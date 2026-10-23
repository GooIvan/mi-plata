-- Cuánto entró o salió de cada cuenta en cada mes.
--
-- Con esto y el saldo inicial de cada cuenta se reconstruye el dinero que había
-- al cierre de cualquier mes, sin guardar saldos históricos. Es la misma suma
-- que hace v_account_balances, agrupada por mes:
--   ingreso: suma · gasto: resta · transferencia: resta en el origen y suma
--   en el destino.
-- security_invoker hace que la vista respete el RLS de quien consulta.

create view public.v_monthly_account_flows
with (security_invoker = true) as
with flows as (
  select
    user_id,
    account_id,
    transaction_date,
    case type when 'income' then amount else -amount end as amount
  from public.transactions
  union all
  select user_id, destination_account_id, transaction_date, amount
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

revoke all on public.v_monthly_account_flows from anon;
grant select on public.v_monthly_account_flows to authenticated;
