-- Totales mensuales de ingresos y gastos, por categoría y moneda.
--
-- Las transferencias no cuentan: mover dinero entre cuentas no es ingresar
-- ni gastar. security_invoker hace que la vista respete el RLS de quien consulta.

create view public.v_monthly_totals
with (security_invoker = true) as
select
  t.user_id,
  date_trunc('month', t.transaction_date)::date as month,
  a.currency,
  t.type,
  t.category_id,
  sum(t.amount) as total,
  count(*) as movements
from public.transactions t
join public.accounts a on a.id = t.account_id
where t.type in ('income', 'expense')
group by 1, 2, 3, 4, 5;

revoke all on public.v_monthly_totals from anon;
grant select on public.v_monthly_totals to authenticated;
