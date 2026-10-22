-- Initial schema (Phase 1): accounts, categories and transactions.

-- Types -----------------------------------------------------------------

create type public.account_type as enum ('cash', 'bank', 'wallet', 'card');
create type public.category_type as enum ('income', 'expense');
create type public.transaction_type as enum ('income', 'expense', 'transfer');

-- Accounts --------------------------------------------------------------

create table public.accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (length(btrim(name)) > 0),
  type public.account_type not null,
  initial_balance numeric(14, 2) not null default 0,
  currency char(3) not null default 'COP' check (currency ~ '^[A-Z]{3}$'),
  is_archived boolean not null default false,
  created_at timestamptz not null default now(),
  unique (id, user_id)
);

create index accounts_user_idx on public.accounts (user_id);
create unique index accounts_name_active_uq
  on public.accounts (user_id, lower(name)) where not is_archived;

-- Categories ------------------------------------------------------------

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null check (length(btrim(name)) > 0),
  type public.category_type not null,
  icon text,
  color text,
  is_archived boolean not null default false,
  created_at timestamptz not null default now(),
  unique (id, user_id)
);

create index categories_user_idx on public.categories (user_id);
create unique index categories_name_active_uq
  on public.categories (user_id, type, lower(name)) where not is_archived;

-- Transactions ----------------------------------------------------------
-- A transfer is a single row: money leaves account_id and enters
-- destination_account_id. It counts as neither income nor expense.
-- Debt payments (Phase 2) will also generate a transaction.

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  type public.transaction_type not null,
  account_id uuid not null,
  destination_account_id uuid,
  category_id uuid,
  amount numeric(14, 2) not null check (amount > 0),
  transaction_date date not null default current_date,
  description text,
  created_at timestamptz not null default now(),
  -- References include user_id so a row can never point to someone else's data.
  foreign key (account_id, user_id) references public.accounts (id, user_id),
  foreign key (destination_account_id, user_id) references public.accounts (id, user_id),
  foreign key (category_id, user_id) references public.categories (id, user_id),
  check ((type = 'transfer') = (destination_account_id is not null)),
  check (destination_account_id is distinct from account_id),
  check (type <> 'transfer' or category_id is null)
);

create index transactions_user_date_idx
  on public.transactions (user_id, transaction_date desc, created_at desc);
create index transactions_account_idx on public.transactions (account_id);
create index transactions_destination_account_idx
  on public.transactions (destination_account_id) where destination_account_id is not null;
create index transactions_category_idx
  on public.transactions (category_id) where category_id is not null;

-- Rules across tables that a CHECK cannot express: the category must be
-- of the same type as the transaction, and transfers only happen between
-- accounts with the same currency.
-- (Error messages are in Spanish because they reach the user.)
create function public.validate_transaction()
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
      raise exception 'Una categoría de tipo % no sirve para un movimiento de tipo %',
        v_category_type, new.type
        using errcode = 'check_violation';
    end if;
  end if;

  if new.type = 'transfer' then
    select currency into v_source_currency
    from public.accounts where id = new.account_id;
    select currency into v_destination_currency
    from public.accounts where id = new.destination_account_id;

    if v_source_currency <> v_destination_currency then
      raise exception 'Una transferencia requiere cuentas de la misma moneda'
        using errcode = 'check_violation';
    end if;
  end if;

  return new;
end;
$$;

create trigger transactions_validate
  before insert or update on public.transactions
  for each row execute function public.validate_transaction();

-- Balances --------------------------------------------------------------
-- Balances are never stored: they are computed from the transactions.
-- security_invoker makes the view respect the RLS of whoever queries it.

create view public.v_account_balances
with (security_invoker = true) as
with flows as (
  select account_id, case type when 'income' then amount else -amount end as amount
  from public.transactions
  union all
  select destination_account_id, amount
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

-- Security (RLS) --------------------------------------------------------

alter table public.accounts enable row level security;
alter table public.categories enable row level security;
alter table public.transactions enable row level security;

create policy "accounts: own rows only" on public.accounts
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "categories: own rows only" on public.categories
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "transactions: own rows only" on public.transactions
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

revoke all on public.accounts, public.categories, public.transactions,
  public.v_account_balances from anon;
grant select, insert, update, delete
  on public.accounts, public.categories, public.transactions to authenticated;
grant select on public.v_account_balances to authenticated;

-- Default categories for every new user ---------------------------------
-- Names are user-facing data, so they stay in Spanish.

create function public.create_default_categories()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.categories (user_id, name, type)
  select new.id, c.name, c.type
  from (values
    ('Alimentación', 'expense'::public.category_type),
    ('Mercado', 'expense'),
    ('Transporte', 'expense'),
    ('Vivienda', 'expense'),
    ('Servicios', 'expense'),
    ('Salud', 'expense'),
    ('Educación', 'expense'),
    ('Entretenimiento', 'expense'),
    ('Ropa', 'expense'),
    ('Otros gastos', 'expense'),
    ('Salario', 'income'),
    ('Ingresos extra', 'income'),
    ('Otros ingresos', 'income')
  ) as c (name, type);

  return new;
end;
$$;

revoke execute on function public.create_default_categories()
  from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.create_default_categories();
