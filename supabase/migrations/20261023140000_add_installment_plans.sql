-- Deudas en cuotas: una compra que se paga de a poco.
--
-- Es una deuda ("Debo") con un plan de pago recurrente ligado a ella. El plan
-- avisa cuándo toca cada cuota (igual que cualquier pago recurrente: no
-- descuenta nada hasta que el usuario confirma), y al confirmar se registra un
-- abono a la deuda, así que lo que falta por pagar va bajando. El plan termina
-- solo cuando la deuda queda saldada.
--
--  * recurring_payments.debt_id: la deuda a la que abona (una por plan).
--  * recurring_payments.installments: cuántas cuotas se pactaron; solo sirve
--    para decir "cuota 4 de 12". Lo que manda es la deuda: si se omite una
--    cuota, el plan sigue hasta que se pague todo.
--  * v_recurring_payments: los pagos recurrentes con lo que falta de su deuda y
--    cuántas cuotas se llevan pagadas.
--  * create_installment_debt: crea la deuda y su plan juntos.

alter table public.recurring_payments
  add column debt_id uuid,
  add column installments smallint check (installments between 1 and 360),
  add foreign key (debt_id, user_id)
    references public.debts (id, user_id) on delete cascade,
  add constraint recurring_payments_installments_need_debt
    check (installments is null or debt_id is not null);

-- Un plan por deuda.
create unique index recurring_payments_debt_uq
  on public.recurring_payments (debt_id) where debt_id is not null;

-- Un plan de cuotas termina cuando la deuda se salda, aunque no tenga fecha
-- final.
alter table public.recurring_payments
  drop constraint recurring_payments_check,
  add constraint recurring_payments_check
    check (next_due_date is not null or end_date is not null or debt_id is not null);

-- Reglas que un CHECK no puede expresar. (Los mensajes llegan al usuario.)
create or replace function public.validate_recurring_payment()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_type public.category_type;
  v_direction public.debt_direction;
  v_debt_currency char(3);
  v_account_currency char(3);
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

  if new.debt_id is not null then
    select direction, currency into v_direction, v_debt_currency
    from public.debts where id = new.debt_id;

    if found and v_direction <> 'payable'::public.debt_direction then
      raise exception 'Solo las deudas que debes pueden pagarse en cuotas'
        using errcode = 'check_violation', detail = 'installment_debt_direction';
    end if;

    select currency into v_account_currency
    from public.accounts where id = new.account_id;

    if found and v_debt_currency is not null
       and v_account_currency <> v_debt_currency then
      raise exception 'La cuenta de las cuotas tiene que ser de la moneda de la deuda'
        using errcode = 'check_violation', detail = 'installment_account_currency';
    end if;
  end if;

  return new;
end;
$$;

-- Los pagos recurrentes con lo que falta de su deuda y las cuotas pagadas.
create view public.v_recurring_payments
with (security_invoker = true) as
select
  r.id,
  r.user_id,
  r.name,
  r.amount,
  r.account_id,
  r.category_id,
  r.every,
  r.unit,
  r.next_due_date,
  r.anchor_day,
  r.end_date,
  r.is_paused,
  r.debt_id,
  r.installments,
  b.remaining as debt_remaining,
  (
    select count(*) from public.debt_payments p where p.debt_id = r.debt_id
  ) as installments_paid
from public.recurring_payments r
left join public.v_debt_balances b on b.id = r.debt_id;

revoke all on public.v_recurring_payments from anon;
grant select on public.v_recurring_payments to authenticated;

-- Operaciones atómicas ---------------------------------------------------

-- Confirma que se pagó. Un pago normal crea un gasto; el de un plan de cuotas
-- registra un abono a la deuda (que también es un gasto, ligado a ella). En los
-- dos casos la regla pasa a la fecha siguiente, y si la deuda queda saldada el
-- plan termina.
create or replace function public.confirm_recurring_payment(
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
  v_description text;
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

  v_description := coalesce(nullif(btrim(p_description), ''), v.name);

  if v.debt_id is null then
    insert into public.transactions
      (type, account_id, category_id, amount, transaction_date, description,
       recurring_payment_id)
    values
      ('expense', p_account_id, v.category_id, p_amount, p_date, v_description, p_id)
    returning id into v_transaction_id;
  else
    -- El abono valida la deuda, la moneda y que no se pase de lo que falta.
    v_transaction_id := public.register_debt_payment(
      v.debt_id, p_account_id, p_amount, p_date, v_description
    );
    update public.transactions
    set category_id = v.category_id, recurring_payment_id = p_id
    where id = v_transaction_id;
  end if;

  v_next := public.recurring_advance(v.next_due_date, v.every, v.unit, v.anchor_day);
  update public.recurring_payments
  set next_due_date = case
    when end_date is not null and v_next > end_date then null
    when debt_id is not null and (
      select remaining from public.v_debt_balances where id = debt_id
    ) <= 0 then null
    else v_next
  end
  where id = p_id;

  return v_transaction_id;
end;
$$;

-- Omite el pago que toca. Si la deuda del plan ya estaba saldada, el plan
-- termina.
create or replace function public.skip_recurring_payment(p_id uuid)
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
    when debt_id is not null and (
      select remaining from public.v_debt_balances where id = debt_id
    ) <= 0 then null
    else v_next
  end
  where id = p_id;
end;
$$;

-- Crea una compra a cuotas: la deuda (lo que se va a pagar en total) y su plan
-- (cuántas cuotas, de cuánto, cada cuánto y desde cuándo), todo o nada. La
-- deuda es en la moneda de la cuenta de la que se pagan las cuotas. No mueve
-- dinero: lo que se compró no entra a ninguna cuenta.
create function public.create_installment_debt(
  p_counterparty text,
  p_amount numeric,
  p_installments int,
  p_installment_amount numeric,
  p_every int,
  p_unit public.recurrence_unit,
  p_first_due date,
  p_account_id uuid,
  p_category_id uuid default null,
  p_start_date date default current_date,
  p_notes text default null
)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_currency char(3);
  v_debt_id uuid;
begin
  select currency into v_currency
  from public.accounts where id = p_account_id;
  if not found then
    raise exception 'La cuenta no existe'
      using errcode = 'foreign_key_violation', detail = 'account_not_found';
  end if;

  v_debt_id := public.create_debt(
    'payable'::public.debt_direction,
    p_counterparty,
    p_amount,
    p_start_date,
    null,
    p_notes,
    null,
    null,
    v_currency
  );

  insert into public.recurring_payments
    (name, amount, account_id, category_id, every, unit, next_due_date,
     anchor_day, debt_id, installments)
  values
    (btrim(p_counterparty), p_installment_amount, p_account_id, p_category_id,
     p_every, p_unit, p_first_due, extract(day from p_first_due)::int,
     v_debt_id, p_installments);

  return v_debt_id;
end;
$$;

revoke execute on function public.create_installment_debt(
  text, numeric, int, numeric, int, public.recurrence_unit, date, uuid, uuid, date, text
) from public, anon;
grant execute on function public.create_installment_debt(
  text, numeric, int, numeric, int, public.recurrence_unit, date, uuid, uuid, date, text
) to authenticated;
