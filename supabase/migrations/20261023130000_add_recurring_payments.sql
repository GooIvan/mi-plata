-- Pagos recurrentes (suscripciones, arriendo...).
--
-- Una regla dice qué se paga, cuánto, desde qué cuenta y cada cuánto. No
-- descuenta nada sola: guarda la fecha del próximo pago (next_due_date), la app
-- avisa cuando se acerca y es el usuario quien confirma que pagó. Solo entonces
-- se crea el gasto de verdad (confirm_recurring_payment) y la regla pasa a la
-- fecha siguiente. También se puede omitir un pago (skip_recurring_payment).
--
--  * every + unit: "cada 1 mes", "cada 2 semanas", "cada 1 año"...
--  * anchor_day: el día del mes que se quiere conservar. Un pago del 31 cae el
--    28 en febrero y vuelve al 31 en marzo (no se va corriendo hacia el 28).
--  * next_due_date null: la regla terminó (pasó su end_date).
--  * is_paused: no se avisa mientras esté en pausa.
--  * transactions.recurring_payment_id: de qué regla viene cada gasto; si se
--    borra la regla, los gastos se quedan.

create type public.recurrence_unit as enum ('week', 'month', 'year');

create table public.recurring_payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (length(btrim(name)) > 0),
  amount numeric(14, 2) not null check (amount > 0),
  -- La cuenta de la que normalmente sale; al confirmar se puede elegir otra.
  account_id uuid not null,
  category_id uuid,
  every smallint not null default 1 check (every between 1 and 99),
  unit public.recurrence_unit not null default 'month',
  next_due_date date,
  anchor_day smallint not null check (anchor_day between 1 and 31),
  end_date date,
  is_paused boolean not null default false,
  created_at timestamptz not null default now(),
  unique (id, user_id),
  foreign key (account_id, user_id) references public.accounts (id, user_id),
  foreign key (category_id, user_id) references public.categories (id, user_id),
  -- Sin próxima fecha solo si ya terminó.
  check (next_due_date is not null or end_date is not null)
);

create index recurring_payments_user_idx on public.recurring_payments (user_id);
create index recurring_payments_due_idx
  on public.recurring_payments (user_id, next_due_date);

alter table public.transactions
  add column recurring_payment_id uuid,
  add foreign key (recurring_payment_id, user_id)
    references public.recurring_payments (id, user_id)
    on delete set null (recurring_payment_id);

create index transactions_recurring_idx
  on public.transactions (recurring_payment_id)
  where recurring_payment_id is not null;

-- Reglas que un CHECK no puede expresar. (Los mensajes llegan al usuario; el
-- código de detail es el que la app traduce.)
create function public.validate_recurring_payment()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_type public.category_type;
begin
  if new.category_id is not null then
    select type into v_type
    from public.categories where id = new.category_id;

    if found and v_type <> 'expense'::public.category_type then
      raise exception 'Solo las categorías de gasto sirven en un pago recurrente'
        using errcode = 'check_violation', detail = 'recurring_category_mismatch';
    end if;
  end if;

  if new.next_due_date is not null
     and new.end_date is not null
     and new.end_date < new.next_due_date then
    raise exception 'La fecha final no puede ser anterior al próximo pago'
      using errcode = 'check_violation', detail = 'recurring_end_before_due';
  end if;

  return new;
end;
$$;

create trigger recurring_payments_validate
  before insert or update on public.recurring_payments
  for each row execute function public.validate_recurring_payment();

-- Fechas ------------------------------------------------------------------

-- La fecha que sigue a p_date: cada p_every semanas, meses o años. En meses y
-- años se conserva el día p_anchor (o el último del mes si no existe).
create function public.recurring_advance(
  p_date date,
  p_every int,
  p_unit public.recurrence_unit,
  p_anchor int
)
returns date
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_first date;
begin
  if p_unit = 'week' then
    return p_date + 7 * p_every;
  end if;

  v_first := (
    date_trunc('month', p_date::timestamp)
    + make_interval(months => p_every * case p_unit when 'year' then 12 else 1 end)
  )::date;

  return v_first + (
    least(
      p_anchor,
      extract(day from (v_first + interval '1 month' - interval '1 day'))::int
    ) - 1
  );
end;
$$;

-- Operaciones atómicas ---------------------------------------------------
-- Corren con los permisos de quien las llama, así que el RLS sigue aplicando.

-- Confirma que se pagó: crea el gasto (en la cuenta, el monto y la fecha que se
-- diga; el nombre de la regla si no hay descripción) y pasa la regla al
-- siguiente pago. Devuelve el id del movimiento.
create function public.confirm_recurring_payment(
  p_id uuid,
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
  v public.recurring_payments;
  v_transaction_id uuid;
  v_next date;
begin
  select * into v from public.recurring_payments where id = p_id for update;
  if not found then
    raise exception 'El pago recurrente no existe'
      using errcode = 'foreign_key_violation', detail = 'recurring_not_found';
  end if;
  if v.next_due_date is null then
    raise exception 'Este pago recurrente ya terminó'
      using errcode = 'check_violation', detail = 'recurring_finished';
  end if;

  insert into public.transactions
    (type, account_id, category_id, amount, transaction_date, description,
     recurring_payment_id)
  values (
    'expense', p_account_id, v.category_id, p_amount, p_date,
    coalesce(nullif(btrim(p_description), ''), v.name), p_id
  )
  returning id into v_transaction_id;

  v_next := public.recurring_advance(v.next_due_date, v.every, v.unit, v.anchor_day);
  update public.recurring_payments
  set next_due_date = case
    when end_date is not null and v_next > end_date then null
    else v_next
  end
  where id = p_id;

  return v_transaction_id;
end;
$$;

-- Omite el pago que toca (no se pagó ni se va a pagar): sin movimiento, la
-- regla pasa al siguiente.
create function public.skip_recurring_payment(p_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v public.recurring_payments;
  v_next date;
begin
  select * into v from public.recurring_payments where id = p_id for update;
  if not found then
    raise exception 'El pago recurrente no existe'
      using errcode = 'foreign_key_violation', detail = 'recurring_not_found';
  end if;
  if v.next_due_date is null then
    raise exception 'Este pago recurrente ya terminó'
      using errcode = 'check_violation', detail = 'recurring_finished';
  end if;

  v_next := public.recurring_advance(v.next_due_date, v.every, v.unit, v.anchor_day);
  update public.recurring_payments
  set next_due_date = case
    when end_date is not null and v_next > end_date then null
    else v_next
  end
  where id = p_id;
end;
$$;

-- Seguridad (RLS) --------------------------------------------------------

alter table public.recurring_payments enable row level security;

create policy "recurring_payments: own rows only" on public.recurring_payments
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

revoke all on public.recurring_payments from anon;
grant select, insert, update, delete on public.recurring_payments to authenticated;

revoke execute on function public.recurring_advance(date, int, public.recurrence_unit, int)
  from public, anon;
revoke execute on function public.confirm_recurring_payment(uuid, uuid, numeric, date, text)
  from public, anon;
revoke execute on function public.skip_recurring_payment(uuid) from public, anon;
grant execute on function public.recurring_advance(date, int, public.recurrence_unit, int)
  to authenticated;
grant execute on function public.confirm_recurring_payment(uuid, uuid, numeric, date, text)
  to authenticated;
grant execute on function public.skip_recurring_payment(uuid) to authenticated;
