-- Datos de una tarjeta de crédito: cupo, día de corte y día límite de pago.
--
-- Son opcionales y solo sirven en cuentas de tipo tarjeta. Lo que se debe y lo
-- que queda disponible NO se guardan: se calculan con el saldo de la cuenta
-- (que ya es negativo cuando se debe), igual que el resto de los saldos.
--
--  * credit_limit: cuánto deja gastar el banco (el cupo).
--  * statement_day: el día del mes en que cierra el extracto (el corte).
--  * payment_day: el día del mes hasta el que hay que pagarlo. Si el mes es más
--    corto que el día pedido (un corte "31" en abril), vale el último día.
--  * Los dos días van juntos: o se dan los dos o ninguno.

alter table public.accounts
  add column credit_limit numeric(14, 2)
    check (credit_limit is null or credit_limit > 0),
  add column statement_day smallint
    check (statement_day between 1 and 31),
  add column payment_day smallint
    check (payment_day between 1 and 31),
  add constraint accounts_card_terms_only_cards
    check (
      type = 'card'
      or (credit_limit is null and statement_day is null and payment_day is null)
    ),
  add constraint accounts_card_days_together
    check ((statement_day is null) = (payment_day is null));

-- Los saldos, ahora con los datos de la tarjeta (las columnas nuevas van al
-- final: así se puede reemplazar la vista sin borrarla).
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
  a.initial_balance + coalesce(sum(f.amount), 0) as current_balance,
  a.credit_limit,
  a.statement_day,
  a.payment_day
from public.accounts a
left join flows f on f.account_id = a.id
group by a.id;
