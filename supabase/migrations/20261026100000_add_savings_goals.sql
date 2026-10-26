-- Metas de ahorro.
--
-- Una meta es "quiero juntar X en esta cuenta (para esta fecha)". El avance es
-- el saldo de la cuenta, que ya se calcula a partir de los movimientos: no se
-- guarda ningún avance aparte, así que el dinero no se cuenta dos veces. Para
-- ahorrar, se transfiere plata a esa cuenta.
--
--  * Una cuenta tiene una sola meta activa: si dos metas compartieran la
--    cuenta, su avance sería el mismo dinero.
--  * Una tarjeta no puede ser la cuenta de una meta (su saldo es una deuda).
--  * Las metas se archivan en lugar de borrarse, y al archivar una meta su
--    cuenta queda libre para otra.
--  * El monto está en la moneda de la cuenta.

create table public.savings_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (length(btrim(name)) > 0),
  target_amount numeric(14, 2) not null check (target_amount > 0),
  account_id uuid not null,
  target_date date,
  is_archived boolean not null default false,
  created_at timestamptz not null default now(),
  unique (id, user_id),
  foreign key (account_id, user_id) references public.accounts (id, user_id)
);

create index savings_goals_user_idx on public.savings_goals (user_id);
create unique index savings_goals_account_active_uq
  on public.savings_goals (account_id) where not is_archived;

-- Una tarjeta no es un lugar donde se ahorra. (El mensaje llega al usuario.)
create function public.validate_savings_goal()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_type public.account_type;
begin
  select type into v_type from public.accounts where id = new.account_id;

  -- Si la cuenta no existe (o es de otro usuario), la llave foránea da el
  -- error que corresponde.
  if found and v_type = 'card'::public.account_type then
    raise exception 'Una tarjeta no puede ser la cuenta de una meta de ahorro'
      using errcode = 'check_violation', detail = 'goal_account_card';
  end if;

  return new;
end;
$$;

create trigger savings_goals_validate
  before insert or update on public.savings_goals
  for each row execute function public.validate_savings_goal();

-- Seguridad (RLS) --------------------------------------------------------

alter table public.savings_goals enable row level security;

create policy "savings_goals: own rows only" on public.savings_goals
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

revoke all on public.savings_goals from anon;
grant select, insert, update, delete on public.savings_goals to authenticated;
