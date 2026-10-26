-- Multimoneda.
--
-- Cada cuenta ya tenía su moneda; ahora se pueden sumar todas en la moneda base
-- del usuario, con tasas de cambio que él mismo define.
--
--  * user_settings: la moneda base (COP por defecto, también si no hay fila).
--  * exchange_rates: cuánto vale 1 unidad de cada moneda en la moneda base.
--    Una tasa por moneda: no hay historial, los totales usan la de hoy.
--  * transactions.destination_amount: lo que llega a la cuenta de destino en
--    una transferencia entre monedas distintas (monto que sale / monto que
--    llega). Si es null, llega lo mismo que sale.
--  * set_exchange_rate / set_base_currency: operaciones atómicas. Cambiar la
--    moneda base reexpresa las tasas y los presupuestos en la moneda nueva.
--  * create_debt acepta la moneda de la deuda cuando no se registra en una cuenta.

-- Preferencias ----------------------------------------------------------

create table public.user_settings (
  user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  base_currency char(3) not null default 'COP' check (base_currency ~ '^[A-Z]{3}$'),
  updated_at timestamptz not null default now()
);

-- Tasas de cambio -------------------------------------------------------

create table public.exchange_rates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  currency char(3) not null check (currency ~ '^[A-Z]{3}$'),
  -- 1 unidad de `currency` vale `rate` unidades de la moneda base.
  rate numeric(20, 10) not null check (rate > 0),
  updated_at timestamptz not null default now(),
  unique (user_id, currency)
);

-- La moneda base no necesita tasa (vale 1). (El mensaje llega al usuario.)
create function public.validate_exchange_rate()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_base char(3);
begin
  select base_currency into v_base
  from public.user_settings where user_id = new.user_id;

  if new.currency = coalesce(v_base, 'COP') then
    raise exception 'La moneda base no necesita tasa de cambio'
      using errcode = 'check_violation', detail = 'rate_for_base_currency';
  end if;

  return new;
end;
$$;

create trigger exchange_rates_validate
  before insert or update on public.exchange_rates
  for each row execute function public.validate_exchange_rate();

-- Transferencias entre monedas ------------------------------------------

alter table public.transactions
  add column destination_amount numeric(14, 2) check (destination_amount > 0),
  add constraint transactions_destination_amount_transfer_only
    check (destination_amount is null or type = 'transfer');

-- Una transferencia entre monedas distintas dice cuánto llega; entre la misma
-- moneda, llega lo mismo que sale y no hay nada que decir.
create or replace function public.validate_transaction()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_category_type public.category_type;
  v_source_currency char(3);
  v_destination_currency char(3);
begin
  if new.category_id is not null then
    select type into v_category_type
    from public.categories where id = new.category_id;

    if v_category_type::text <> new.type::text then
      raise exception 'La categoría elegida no corresponde a este tipo de movimiento'
        using errcode = 'check_violation', detail = 'transaction_category_mismatch';
    end if;
  end if;

  if new.type = 'transfer' then
    select currency into v_source_currency
    from public.accounts where id = new.account_id;
    select currency into v_destination_currency
    from public.accounts where id = new.destination_account_id;

    if v_source_currency <> v_destination_currency then
      if new.destination_amount is null then
        raise exception 'Una transferencia entre monedas distintas necesita el monto que llega'
          using errcode = 'check_violation',
                detail = 'transfer_destination_amount_required';
      end if;
    elsif new.destination_amount is not null then
      raise exception 'El monto que llega solo se indica en transferencias entre monedas distintas'
        using errcode = 'check_violation',
              detail = 'transfer_destination_amount_unexpected';
    end if;
  end if;

  return new;
end;
$$;

-- Los saldos suman lo que llega, no lo que sale.
create or replace view public.v_account_balances
with (security_invoker = true) as
with flows as (
  select account_id, case type when 'income' then amount else -amount end as amount
  from public.transactions
  union all
  select destination_account_id, coalesce(destination_amount, amount)
  from public.transactions
  where type = 'transfer'
)
select
  a.id,
  a.user_id,
  a.name,
  a.type,
  a.currency,
  a.is_archived,
  a.initial_balance,
  a.initial_balance + coalesce(sum(f.amount), 0) as current_balance
from public.accounts a
left join flows f on f.account_id = a.id
group by a.id;

create or replace view public.v_monthly_account_flows
with (security_invoker = true) as
with flows as (
  select
    user_id,
    account_id,
    transaction_date,
    case type when 'income' then amount else -amount end as amount
  from public.transactions
  union all
  select user_id, destination_account_id, transaction_date,
         coalesce(destination_amount, amount)
  from public.transactions
  where type = 'transfer'
)
select
  f.user_id,
  date_trunc('month', f.transaction_date)::date as month,
  f.account_id,
  a.currency,
  sum(f.amount) as flow
from flows f
join public.accounts a on a.id = f.account_id
group by 1, 2, 3, 4;

-- Operaciones atómicas ---------------------------------------------------
-- Corren con los permisos de quien las llama, así que el RLS sigue aplicando.

-- Define (o cambia) cuánto vale 1 unidad de p_currency en la moneda base.
create function public.set_exchange_rate(p_currency char(3), p_rate numeric)
returns void
language plpgsql
set search_path = ''
as $$
begin
  insert into public.exchange_rates (currency, rate)
  values (p_currency, p_rate)
  on conflict (user_id, currency)
  do update set rate = excluded.rate, updated_at = now();
end;
$$;

-- Cambia la moneda base. Las tasas y los presupuestos están expresados en la
-- moneda base, así que se reexpresan en la nueva.
--
-- p_rate es cuánto vale 1 unidad de la moneda nueva en la base de ahora; si no
-- se da, se usa la tasa guardada. Hace falta cuando hay tasas o presupuestos
-- que convertir.
create function public.set_base_currency(p_currency char(3), p_rate numeric default null)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_old char(3);
  v_rate numeric;
begin
  select base_currency into v_old
  from public.user_settings where user_id = auth.uid();
  v_old := coalesce(v_old, 'COP');

  if p_currency = v_old then
    return;
  end if;

  v_rate := coalesce(
    p_rate,
    (select rate from public.exchange_rates where currency = p_currency)
  );

  if v_rate is null
     and (exists (select 1 from public.exchange_rates)
          or exists (select 1 from public.budgets)) then
    raise exception 'Hace falta la tasa de la moneda nueva para convertir tus tasas y presupuestos'
      using errcode = 'check_violation', detail = 'base_rate_required';
  end if;

  -- Una tasa de la moneda nueva ya no tiene sentido: pasa a ser la base.
  delete from public.exchange_rates where currency = p_currency;

  -- La base cambia antes de tocar las tasas: el disparador de las tasas
  -- rechaza una tasa para la moneda base, y la vieja dejará de serlo.
  insert into public.user_settings (base_currency)
  values (p_currency)
  on conflict (user_id)
  do update set base_currency = excluded.base_currency, updated_at = now();

  if v_rate is not null then
    -- 1 X = q (base vieja) = q / v_rate (base nueva). (El WHERE es explícito:
    -- la API de Supabase rechaza un UPDATE sin él, aunque el RLS ya filtre.)
    update public.exchange_rates set rate = rate / v_rate
    where user_id = auth.uid();

    -- La base vieja ahora es una moneda más: 1 vieja = 1 / v_rate nueva.
    insert into public.exchange_rates (currency, rate, updated_at)
    values (v_old, 1 / v_rate, now())
    on conflict (user_id, currency)
    do update set rate = excluded.rate, updated_at = now();

    update public.budgets set amount = round(amount / v_rate, 2)
    where user_id = auth.uid();
  end if;
end;
$$;

-- Deudas en otra moneda ---------------------------------------------------
-- Sin cuenta, la deuda es en p_currency (si no se da, en la moneda base). Con
-- cuenta, es en la moneda de la cuenta. La firma cambia (parámetro nuevo): se
-- reemplaza la función y se vuelven a dar los permisos.

drop function public.create_debt(
  public.debt_direction, text, numeric, date, date, text, uuid, text
);

create function public.create_debt(
  p_direction public.debt_direction,
  p_counterparty text,
  p_amount numeric,
  p_start_date date default current_date,
  p_due_date date default null,
  p_notes text default null,
  p_account_id uuid default null,
  p_description text default null,
  p_currency char(3) default null
)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_id uuid;
  v_currency char(3);
begin
  if p_account_id is not null then
    select currency into v_currency
    from public.accounts where id = p_account_id;
    if not found then
      raise exception 'La cuenta no existe'
        using errcode = 'foreign_key_violation', detail = 'account_not_found';
    end if;
  else
    v_currency := coalesce(
      p_currency,
      (select base_currency from public.user_settings where user_id = auth.uid()),
      'COP'
    );
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
      coalesce(
        nullif(btrim(p_description), ''),
        case p_direction when 'payable' then 'Préstamo de ' else 'Préstamo a ' end
          || btrim(p_counterparty)
      )
    );
  end if;

  return v_id;
end;
$$;

-- Seguridad (RLS) --------------------------------------------------------

alter table public.user_settings enable row level security;
alter table public.exchange_rates enable row level security;

create policy "user_settings: own row only" on public.user_settings
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "exchange_rates: own rows only" on public.exchange_rates
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

revoke all on public.user_settings, public.exchange_rates from anon;
grant select, insert, update, delete
  on public.user_settings, public.exchange_rates to authenticated;

revoke execute on function public.set_exchange_rate(char, numeric) from public, anon;
revoke execute on function public.set_base_currency(char, numeric) from public, anon;
grant execute on function public.set_exchange_rate(char, numeric) to authenticated;
grant execute on function public.set_base_currency(char, numeric) to authenticated;

revoke execute on function public.create_debt(
  public.debt_direction, text, numeric, date, date, text, uuid, text, char
) from public, anon;
grant execute on function public.create_debt(
  public.debt_direction, text, numeric, date, date, text, uuid, text, char
) to authenticated;
