-- Deudas (Fase 2): lo que debo y lo que me deben, con sus abonos.
--
-- Un abono es un movimiento de verdad (un gasto si yo debo, un ingreso si me
-- deben) enlazado a la deuda: el dinero cuadra en las cuentas y lo pagado de
-- cada deuda se calcula a partir de esos movimientos, nunca se guarda.

create type public.debt_direction as enum ('payable', 'receivable');
-- payable: yo debo. receivable: me deben.

-- Deudas ----------------------------------------------------------------

create table public.debts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  direction public.debt_direction not null,
  counterparty text not null check (length(btrim(counterparty)) > 0),
  amount numeric(14, 2) not null check (amount > 0),
  currency char(3) not null default 'COP' check (currency ~ '^[A-Z]{3}$'),
  start_date date not null default current_date,
  due_date date,
  notes text,
  is_archived boolean not null default false,
  created_at timestamptz not null default now(),
  unique (id, user_id),
  check (due_date is null or due_date >= start_date)
);

create index debts_user_idx on public.debts (user_id);

-- Abonos ----------------------------------------------------------------
-- Cada abono es una fila que enlaza una deuda con el movimiento que lo hizo.
-- El monto y la fecha viven en el movimiento: si se edita allí, la deuda se
-- recalcula; si se elimina el movimiento, el abono desaparece con él.

alter table public.transactions
  add constraint transactions_id_user_id_key unique (id, user_id);

create table public.debt_payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  debt_id uuid not null,
  transaction_id uuid not null unique,
  created_at timestamptz not null default now(),
  foreign key (debt_id, user_id)
    references public.debts (id, user_id) on delete cascade,
  foreign key (transaction_id, user_id)
    references public.transactions (id, user_id) on delete cascade
);

create index debt_payments_debt_idx on public.debt_payments (debt_id);

-- Reglas que un CHECK no puede expresar -----------------------------------
-- (Los mensajes están en español porque llegan al usuario.)

create function public.validate_debt_payment()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_debt public.debts;
  v_type public.transaction_type;
  v_amount numeric;
  v_currency char(3);
  v_expected public.transaction_type;
  v_paid numeric;
begin
  -- Se bloquea la deuda para que dos abonos simultáneos no se pasen del total.
  select * into v_debt from public.debts where id = new.debt_id for update;
  if not found then
    raise exception 'La deuda no existe' using errcode = 'foreign_key_violation';
  end if;

  select t.type, t.amount, a.currency
    into v_type, v_amount, v_currency
  from public.transactions t
  join public.accounts a on a.id = t.account_id
  where t.id = new.transaction_id;

  v_expected := case v_debt.direction
    when 'payable' then 'expense'::public.transaction_type
    else 'income'::public.transaction_type
  end;
  if v_type is distinct from v_expected then
    raise exception 'El abono no corresponde al tipo de deuda'
      using errcode = 'check_violation';
  end if;

  if v_currency <> v_debt.currency then
    raise exception 'El abono debe ser de una cuenta en la moneda de la deuda'
      using errcode = 'check_violation';
  end if;

  select coalesce(sum(t.amount), 0) into v_paid
  from public.debt_payments p
  join public.transactions t on t.id = p.transaction_id
  where p.debt_id = new.debt_id and p.id is distinct from new.id;

  if v_paid + v_amount > v_debt.amount then
    raise exception 'El abono supera lo que falta por pagar'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

create trigger debt_payments_validate
  before insert or update on public.debt_payments
  for each row execute function public.validate_debt_payment();

-- Una deuda no puede quedar con un monto menor a lo ya pagado, ni cambiar
-- de sentido (debo / me deben) si ya tiene abonos.
create function public.validate_debt_update()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_paid numeric;
begin
  select coalesce(sum(t.amount), 0) into v_paid
  from public.debt_payments p
  join public.transactions t on t.id = p.transaction_id
  where p.debt_id = new.id;

  if new.amount < v_paid then
    raise exception 'El monto no puede ser menor a lo que ya se ha pagado'
      using errcode = 'check_violation';
  end if;

  if new.direction <> old.direction and v_paid > 0 then
    raise exception 'No se puede cambiar el sentido de una deuda que ya tiene abonos'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

create trigger debts_validate_update
  before update on public.debts
  for each row execute function public.validate_debt_update();

-- Un movimiento que es abono de una deuda no puede cambiar de tipo (dejaría
-- de ser un gasto o un ingreso, según el caso). Su monto sí se puede corregir.
create function public.validate_debt_payment_transaction()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.type <> old.type
     and exists (
       select 1 from public.debt_payments where transaction_id = new.id
     ) then
    raise exception 'Este movimiento es el abono de una deuda: no se puede cambiar su tipo'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

create trigger transactions_validate_debt_payment
  before update on public.transactions
  for each row execute function public.validate_debt_payment_transaction();

-- Operaciones atómicas ---------------------------------------------------
-- Se ejecutan completas o no se ejecutan: si algo falla a la mitad, no queda
-- dinero movido sin que la deuda lo sepa. Corren con los permisos de quien las
-- llama, así que el RLS sigue aplicando.

-- Crea una deuda. Con p_account_id, además registra el dinero en esa cuenta:
-- si me prestaron (payable) entra; si presté (receivable) sale.
create function public.create_debt(
  p_direction public.debt_direction,
  p_counterparty text,
  p_amount numeric,
  p_start_date date default current_date,
  p_due_date date default null,
  p_notes text default null,
  p_account_id uuid default null
)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_id uuid;
  v_currency char(3) := 'COP';
begin
  if p_account_id is not null then
    select currency into v_currency
    from public.accounts where id = p_account_id;
    if not found then
      raise exception 'La cuenta no existe' using errcode = 'foreign_key_violation';
    end if;
  end if;

  insert into public.debts
    (direction, counterparty, amount, currency, start_date, due_date, notes)
  values
    (p_direction, btrim(p_counterparty), p_amount, v_currency, p_start_date,
     p_due_date, nullif(btrim(p_notes), ''))
  returning id into v_id;

  if p_account_id is not null then
    insert into public.transactions
      (type, account_id, amount, transaction_date, description)
    values (
      case p_direction
        when 'payable' then 'income'::public.transaction_type
        else 'expense'::public.transaction_type
      end,
      p_account_id,
      p_amount,
      p_start_date,
      case p_direction when 'payable' then 'Préstamo de ' else 'Préstamo a ' end
        || btrim(p_counterparty)
    );
  end if;

  return v_id;
end;
$$;

-- Registra un abono: crea el movimiento (gasto si debo, ingreso si me deben)
-- y lo enlaza a la deuda. Devuelve el id del movimiento.
create function public.register_debt_payment(
  p_debt_id uuid,
  p_account_id uuid,
  p_amount numeric,
  p_date date default current_date,
  p_description text default null
)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_debt public.debts;
  v_transaction_id uuid;
begin
  select * into v_debt from public.debts where id = p_debt_id;
  if not found then
    raise exception 'La deuda no existe' using errcode = 'foreign_key_violation';
  end if;
  if v_debt.is_archived then
    raise exception 'La deuda está archivada: restáurala para registrar abonos'
      using errcode = 'check_violation';
  end if;

  insert into public.transactions
    (type, account_id, amount, transaction_date, description)
  values (
    case v_debt.direction
      when 'payable' then 'expense'::public.transaction_type
      else 'income'::public.transaction_type
    end,
    p_account_id,
    p_amount,
    p_date,
    coalesce(
      nullif(btrim(p_description), ''),
      case v_debt.direction when 'payable' then 'Abono a ' else 'Abono de ' end
        || v_debt.counterparty
    )
  )
  returning id into v_transaction_id;

  insert into public.debt_payments (debt_id, transaction_id)
  values (p_debt_id, v_transaction_id);

  return v_transaction_id;
end;
$$;

revoke execute on function public.create_debt(
  public.debt_direction, text, numeric, date, date, text, uuid
) from public, anon;
revoke execute on function public.register_debt_payment(
  uuid, uuid, numeric, date, text
) from public, anon;
grant execute on function public.create_debt(
  public.debt_direction, text, numeric, date, date, text, uuid
) to authenticated;
grant execute on function public.register_debt_payment(
  uuid, uuid, numeric, date, text
) to authenticated;

-- Vistas -----------------------------------------------------------------
-- Lo pagado y lo pendiente se calculan; security_invoker respeta el RLS.

create view public.v_debt_balances
with (security_invoker = true) as
select
  d.id,
  d.user_id,
  d.direction,
  d.counterparty,
  d.amount,
  d.currency,
  d.start_date,
  d.due_date,
  d.notes,
  d.is_archived,
  coalesce(sum(t.amount), 0) as paid,
  d.amount - coalesce(sum(t.amount), 0) as remaining
from public.debts d
left join public.debt_payments p on p.debt_id = d.id
left join public.transactions t on t.id = p.transaction_id
group by d.id;

create view public.v_debt_payments
with (security_invoker = true) as
select
  p.id,
  p.user_id,
  p.debt_id,
  p.transaction_id,
  t.amount,
  t.transaction_date,
  t.account_id,
  t.description
from public.debt_payments p
join public.transactions t on t.id = p.transaction_id;

-- Seguridad (RLS) --------------------------------------------------------

alter table public.debts enable row level security;
alter table public.debt_payments enable row level security;

create policy "debts: own rows only" on public.debts
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "debt_payments: own rows only" on public.debt_payments
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

revoke all on public.debts, public.debt_payments,
  public.v_debt_balances, public.v_debt_payments from anon;
grant select, insert, update, delete
  on public.debts, public.debt_payments to authenticated;
grant select on public.v_debt_balances, public.v_debt_payments to authenticated;
