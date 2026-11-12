-- Compras diferidas a cuotas con una tarjeta de crédito.
--
-- Una compra diferida es UN gasto de la tarjeta por lo que se va a pagar en
-- total (la compra más los intereses, si los hay) y un plan que dice en cuántas
-- cuotas lo cobra el banco. El gasto baja el saldo de la tarjeta de una vez
-- (así el cupo usado es el real); el plan solo sirve para saber cuánto entra en
-- cada extracto, y se calcula con las fechas de corte: no se guarda nada por
-- cuota.
--
--  * transaction_id: el gasto de la tarjeta (uno por plan). Si el gasto se
--    borra, el plan se borra con él.
--  * purchase_amount: lo que costaba la compra, sin intereses. El total que se
--    paga es el monto del gasto, así que los intereses son la diferencia.
--  * installments / installment_amount: cuántas cuotas y de cuánto cada una. La
--    última cuota es lo que falte para llegar al total.
--  * El gasto no puede cambiar de tipo, de cuenta ni de monto: dejaría de
--    cuadrar con el plan. Se puede cambiar su fecha, categoría y descripción.
--  * create_card_installment_purchase crea el gasto y su plan juntos.

create table public.card_installment_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  transaction_id uuid not null unique,
  purchase_amount numeric(14, 2) not null check (purchase_amount > 0),
  installments smallint not null check (installments between 2 and 60),
  installment_amount numeric(14, 2) not null check (installment_amount > 0),
  created_at timestamptz not null default now(),
  foreign key (transaction_id, user_id)
    references public.transactions (id, user_id) on delete cascade
);

-- Reglas que un CHECK no puede expresar. (Los mensajes llegan al usuario.)
create function public.validate_card_installment_plan()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_type public.transaction_type;
  v_amount numeric;
  v_account_type public.account_type;
begin
  select t.type, t.amount, a.type
  into v_type, v_amount, v_account_type
  from public.transactions t
  join public.accounts a on a.id = t.account_id
  where t.id = new.transaction_id;

  if v_type <> 'expense'::public.transaction_type
     or v_account_type <> 'card'::public.account_type then
    raise exception 'Solo una compra hecha con una tarjeta se puede diferir en cuotas'
      using errcode = 'check_violation', detail = 'installment_purchase_not_card';
  end if;

  -- El total que se paga no puede ser menos que la compra, y las cuotas tienen
  -- que dejar algo para la última.
  if v_amount < new.purchase_amount
     or new.installment_amount * (new.installments - 1) >= v_amount then
    raise exception 'Las cuotas no cuadran con el valor de la compra'
      using errcode = 'check_violation', detail = 'installment_purchase_amounts';
  end if;

  return new;
end;
$$;

create trigger card_installment_plans_validate
  before insert or update on public.card_installment_plans
  for each row execute function public.validate_card_installment_plan();

create function public.validate_card_installment_transaction()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (new.type <> old.type
      or new.account_id <> old.account_id
      or new.amount <> old.amount)
     and exists (
       select 1 from public.card_installment_plans where transaction_id = new.id
     ) then
    raise exception 'Esta compra está diferida en cuotas: para cambiar el monto o la tarjeta, bórrala y regístrala de nuevo'
      using errcode = 'check_violation', detail = 'installment_purchase_locked';
  end if;
  return new;
end;
$$;

create trigger transactions_validate_card_installment
  before update on public.transactions
  for each row execute function public.validate_card_installment_transaction();

-- Los planes con los datos de su gasto, para leerlos de una vez.
create view public.v_card_installment_plans
with (security_invoker = true) as
select
  p.id,
  p.user_id,
  p.transaction_id,
  t.account_id,
  t.category_id,
  t.description,
  t.transaction_date,
  t.amount as total_amount,
  p.purchase_amount,
  p.installments,
  p.installment_amount,
  p.created_at
from public.card_installment_plans p
join public.transactions t on t.id = p.transaction_id;

-- Operaciones atómicas ---------------------------------------------------
-- Corren con los permisos de quien las llama, así que el RLS sigue aplicando.

-- Registra una compra con la tarjeta diferida en cuotas, todo o nada.
--
-- Sin p_installment_amount no hay intereses: la compra se parte en partes
-- iguales (la última absorbe los centavos). Con él, lo que se paga en total son
-- las cuotas completas; los intereses son lo que pasa del valor de la compra.
-- Las cuotas no pueden sumar menos que la compra (salvo el redondeo).
create function public.create_card_installment_purchase(
  p_account_id uuid,
  p_purchase_amount numeric,
  p_installments int,
  p_installment_amount numeric default null,
  p_category_id uuid default null,
  p_date date default current_date,
  p_description text default null
)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_type public.account_type;
  v_installment numeric(14, 2);
  v_total numeric(14, 2);
  v_transaction_id uuid;
begin
  select type into v_type from public.accounts where id = p_account_id;
  if not found then
    raise exception 'La cuenta no existe'
      using errcode = 'foreign_key_violation', detail = 'account_not_found';
  end if;
  if v_type <> 'card'::public.account_type then
    raise exception 'Solo una compra hecha con una tarjeta se puede diferir en cuotas'
      using errcode = 'check_violation', detail = 'installment_purchase_not_card';
  end if;

  if p_installment_amount is null then
    v_installment := round(p_purchase_amount / p_installments, 2);
    v_total := p_purchase_amount;
  else
    -- Las cuotas no pueden sumar menos que la compra (salvo los centavos del
    -- redondeo): sería un error de quien las escribió.
    if p_installment_amount * p_installments
       < p_purchase_amount - p_installments * 0.01 then
      raise exception 'Las cuotas no cuadran con el valor de la compra'
        using errcode = 'check_violation', detail = 'installment_purchase_amounts';
    end if;
    v_installment := p_installment_amount;
    v_total := greatest(p_purchase_amount, round(p_installment_amount * p_installments, 2));
  end if;

  insert into public.transactions
    (type, account_id, category_id, amount, transaction_date, description)
  values
    ('expense', p_account_id, p_category_id, v_total, p_date,
     nullif(btrim(p_description), ''))
  returning id into v_transaction_id;

  insert into public.card_installment_plans
    (transaction_id, purchase_amount, installments, installment_amount)
  values
    (v_transaction_id, p_purchase_amount, p_installments, v_installment);

  return v_transaction_id;
end;
$$;

revoke execute on function public.create_card_installment_purchase(
  uuid, numeric, int, numeric, uuid, date, text
) from public, anon;
grant execute on function public.create_card_installment_purchase(
  uuid, numeric, int, numeric, uuid, date, text
) to authenticated;

-- Permisos ----------------------------------------------------------------

alter table public.card_installment_plans enable row level security;

create policy "card_installment_plans: own rows only"
  on public.card_installment_plans
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

revoke all on public.card_installment_plans, public.v_card_installment_plans
  from anon;
grant select, insert, update, delete
  on public.card_installment_plans to authenticated;
grant select on public.v_card_installment_plans to authenticated;
