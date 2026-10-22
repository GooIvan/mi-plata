-- Presupuestos: cuánto se quiere gastar al mes en una categoría.
--
-- Cada fila dice "desde este mes, el presupuesto de esta categoría es X" y
-- vale hasta que otra fila de un mes posterior lo cambie. Así, subir un
-- presupuesto en noviembre no reescribe cómo se midió octubre. Un monto de 0
-- significa "sin presupuesto desde este mes".

create table public.budgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  category_id uuid not null,
  -- Siempre el primer día del mes.
  effective_month date not null
    check (effective_month = date_trunc('month', effective_month)::date),
  amount numeric(14, 2) not null check (amount >= 0),
  created_at timestamptz not null default now(),
  foreign key (category_id, user_id)
    references public.categories (id, user_id) on delete cascade,
  -- Una categoría es de un solo usuario, así que esto basta para poder
  -- hacer upsert por (categoría, mes).
  unique (category_id, effective_month)
);

create index budgets_user_idx on public.budgets (user_id);

-- Solo las categorías de gasto tienen presupuesto. (El mensaje llega al usuario.)
create function public.validate_budget()
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
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

create trigger budgets_validate
  before insert or update on public.budgets
  for each row execute function public.validate_budget();

-- Seguridad (RLS) --------------------------------------------------------

alter table public.budgets enable row level security;

create policy "budgets: own rows only" on public.budgets
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

revoke all on public.budgets from anon;
grant select, insert, update, delete on public.budgets to authenticated;
