-- Tasas de cambio automáticas.
--
-- Una tasa puede ser manual (la escribió el usuario) o automática (la trajo la
-- app de un servicio de tasas). La manual manda: una actualización automática
-- nunca la pisa. El usuario decide cuál usar para cada moneda.
--
--  * exchange_rates.is_manual: true si la definió el usuario. Las filas que ya
--    existen son manuales (las escribió él).
--  * set_exchange_rate: lo que escribe el usuario, así que deja la tasa manual.
--  * set_automatic_rates(jsonb): recibe {"USD": 4000.5, ...} (cuánto vale 1
--    unidad en la moneda base), crea las que faltan y actualiza solo las
--    automáticas; ignora las manuales y la moneda base. Devuelve cuántas
--    escribió. Todo o nada.

alter table public.exchange_rates
  add column is_manual boolean not null default true;

create or replace function public.set_exchange_rate(p_currency char(3), p_rate numeric)
returns void
language plpgsql
set search_path = ''
as $$
begin
  insert into public.exchange_rates (currency, rate, is_manual)
  values (p_currency, p_rate, true)
  on conflict (user_id, currency)
  do update set rate = excluded.rate, is_manual = true, updated_at = now();
end;
$$;

create function public.set_automatic_rates(p_rates jsonb)
returns int
language plpgsql
set search_path = ''
as $$
declare
  v_base char(3);
  v_count int;
begin
  select base_currency into v_base
  from public.user_settings where user_id = (select auth.uid());
  v_base := coalesce(v_base, 'COP');

  with incoming as (
    select upper(key)::char(3) as currency, value::numeric as rate
    from jsonb_each_text(p_rates)
    where upper(key) ~ '^[A-Z]{3}$'
      and upper(key) <> v_base
      and value::numeric > 0
  ),
  written as (
    insert into public.exchange_rates as r (currency, rate, is_manual)
    select currency, rate, false from incoming
    on conflict (user_id, currency)
    do update set rate = excluded.rate, updated_at = now()
    where not r.is_manual
    returning 1
  )
  select count(*) into v_count from written;

  return v_count;
end;
$$;

revoke execute on function public.set_automatic_rates(jsonb) from public, anon;
grant execute on function public.set_automatic_rates(jsonb) to authenticated;
