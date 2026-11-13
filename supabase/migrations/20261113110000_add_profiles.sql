-- Perfil del usuario: nombres, apellidos, fecha de nacimiento, profesión e
-- ingreso mensual promedio.
--
-- Son datos personales: solo el dueño los ve (RLS) y todos son opcionales en la
-- base de datos; la app decide cuáles pide (nombre y apellido al registrarse).
-- La fecha de nacimiento se guarda en vez de la edad para que no se desactualice.
--
--  * profiles: una fila por usuario. El ingreso va con su moneda; o están los dos
--    o ninguno.
--  * create_profile: al crear el usuario, arma su perfil con los datos que llegan
--    en los metadatos del registro (first_name, last_name, birth_date,
--    profession, monthly_income, monthly_income_currency). Corre en la misma
--    transacción que el registro: si el perfil no es válido, el usuario tampoco
--    se crea, y no queda una cuenta a medias.
--  * Los metadatos del registro (auth.users.raw_user_meta_data) conservan una
--    copia de esos datos: el servicio de autenticación los vuelve a escribir y
--    no es nuestro. El perfil es la fuente de verdad; la copia no se usa ni se
--    actualiza, y se borra junto con la cuenta.

create table public.profiles (
  user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  first_name text check (first_name is null or length(btrim(first_name)) between 1 and 60),
  last_name text check (last_name is null or length(btrim(last_name)) between 1 and 60),
  birth_date date check (birth_date is null or birth_date >= date '1900-01-01'),
  profession text check (profession is null or length(btrim(profession)) between 1 and 80),
  monthly_income numeric(14, 2) check (monthly_income is null or monthly_income > 0),
  monthly_income_currency char(3)
    check (monthly_income_currency is null or monthly_income_currency ~ '^[A-Z]{3}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((monthly_income is null) = (monthly_income_currency is null))
);

-- Reglas que un CHECK no puede expresar. (Los mensajes llegan al usuario.)
create function public.validate_profile()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.birth_date is not null and new.birth_date > current_date then
    raise exception 'La fecha de nacimiento no puede ser futura'
      using errcode = 'check_violation', detail = 'profile_birth_date_future';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_validate
  before insert or update on public.profiles
  for each row execute function public.validate_profile();

-- El perfil nace con el usuario.
create function public.create_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_income numeric := nullif(btrim(v_meta ->> 'monthly_income'), '')::numeric;
begin
  insert into public.profiles
    (user_id, first_name, last_name, birth_date, profession,
     monthly_income, monthly_income_currency)
  values (
    new.id,
    nullif(btrim(v_meta ->> 'first_name'), ''),
    nullif(btrim(v_meta ->> 'last_name'), ''),
    nullif(btrim(v_meta ->> 'birth_date'), '')::date,
    nullif(btrim(v_meta ->> 'profession'), ''),
    v_income,
    case when v_income is null then null
         else coalesce(nullif(upper(btrim(v_meta ->> 'monthly_income_currency')), ''), 'COP')
    end
  );

  return new;
end;
$$;

revoke execute on function public.create_profile() from public, anon, authenticated;

create trigger on_auth_user_created_profile
  after insert on auth.users
  for each row execute function public.create_profile();

-- Permisos ----------------------------------------------------------------

alter table public.profiles enable row level security;

create policy "profiles: own row only" on public.profiles
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

revoke all on public.profiles from anon;
grant select, insert, update, delete on public.profiles to authenticated;
