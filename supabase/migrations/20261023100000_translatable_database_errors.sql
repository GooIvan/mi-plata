-- Errores que se pueden traducir.
--
-- Los mensajes de validación se escribieron en español porque llegaban al
-- usuario tal cual. Ahora la app está en varios idiomas, así que cada error
-- lleva además un código estable en `detail` (PostgREST lo entrega en
-- `details`) y la app muestra el texto en el idioma elegido. El mensaje en
-- español se conserva: sirve para los registros y como respaldo si llega un
-- código que la app no conoce.
--
-- Códigos: transaction_category_mismatch, transfer_currency_mismatch,
-- budget_expense_only, debt_not_found, account_not_found, debt_archived,
-- payment_direction_mismatch, payment_currency_mismatch,
-- payment_exceeds_remaining, payment_type_locked, debt_amount_below_paid,
-- debt_direction_locked.
--
-- Además, `create_debt` acepta la descripción del movimiento que registra
-- (p_description): antes siempre decía "Préstamo de/a ..." en español. La app
-- ahora la manda en el idioma del usuario; sin ella queda el texto de antes.

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
      raise exception 'Una transferencia requiere cuentas de la misma moneda'
        using errcode = 'check_violation', detail = 'transfer_currency_mismatch';
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.validate_budget()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_type public.category_type;
begin
  select type into v_type
  from public.categories where id = new.category_id;

  -- Si la categoría no existe (o es de otro usuario, que aquí no se ve), no se
  -- dice nada: la llave foránea da el error que corresponde.
  if found and v_type <> 'expense'::public.category_type then
    raise exception 'Solo las categorías de gasto pueden tener presupuesto'
      using errcode = 'check_violation', detail = 'budget_expense_only';
  end if;

  return new;
end;
$$;

create or replace function public.validate_debt_payment()
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
    raise exception 'La deuda no existe' using errcode = 'foreign_key_violation', detail = 'debt_not_found';
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
      using errcode = 'check_violation', detail = 'payment_direction_mismatch';
  end if;

  if v_currency <> v_debt.currency then
    raise exception 'El abono debe ser de una cuenta en la moneda de la deuda'
      using errcode = 'check_violation', detail = 'payment_currency_mismatch';
  end if;

  select coalesce(sum(t.amount), 0) into v_paid
  from public.debt_payments p
  join public.transactions t on t.id = p.transaction_id
  where p.debt_id = new.debt_id and p.id is distinct from new.id;

  if v_paid + v_amount > v_debt.amount then
    raise exception 'El abono supera lo que falta por pagar'
      using errcode = 'check_violation', detail = 'payment_exceeds_remaining';
  end if;

  return new;
end;
$$;

create or replace function public.validate_debt_update()
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
      using errcode = 'check_violation', detail = 'debt_amount_below_paid';
  end if;

  if new.direction <> old.direction and v_paid > 0 then
    raise exception 'No se puede cambiar el sentido de una deuda que ya tiene abonos'
      using errcode = 'check_violation', detail = 'debt_direction_locked';
  end if;

  return new;
end;
$$;

create or replace function public.validate_debt_payment_transaction()
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
      using errcode = 'check_violation', detail = 'payment_type_locked';
  end if;
  return new;
end;
$$;

create or replace function public.register_debt_payment(
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
    raise exception 'La deuda no existe' using errcode = 'foreign_key_violation', detail = 'debt_not_found';
  end if;
  if v_debt.is_archived then
    raise exception 'La deuda está archivada: restáurala para registrar abonos'
      using errcode = 'check_violation', detail = 'debt_archived';
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

-- La firma cambia (parámetro nuevo): se reemplaza la función y se vuelven a dar
-- los permisos.
drop function public.create_debt(
  public.debt_direction, text, numeric, date, date, text, uuid
);

create function public.create_debt(
  p_direction public.debt_direction,
  p_counterparty text,
  p_amount numeric,
  p_start_date date default current_date,
  p_due_date date default null,
  p_notes text default null,
  p_account_id uuid default null,
  p_description text default null
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
      raise exception 'La cuenta no existe' using errcode = 'foreign_key_violation', detail = 'account_not_found';
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

revoke execute on function public.create_debt(
  public.debt_direction, text, numeric, date, date, text, uuid, text
) from public, anon;
grant execute on function public.create_debt(
  public.debt_direction, text, numeric, date, date, text, uuid, text
) to authenticated;
