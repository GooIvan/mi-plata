-- Categorías por defecto en el idioma del usuario.
--
-- Las 13 categorías con que empieza cada usuario nuevo siempre se creaban en
-- español. Ahora la app manda el idioma al registrarse (language, en los
-- metadatos del usuario) y se crean en ese idioma; si no llega, o es uno que
-- no tenemos, en español. Los usuarios que ya existen conservan las suyas (son
-- datos del usuario: se pueden renombrar).

create or replace function public.create_default_categories()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.raw_user_meta_data ->> 'language' = 'en' then
    insert into public.categories (user_id, name, type)
    select new.id, c.name, c.type
    from (values
      ('Food', 'expense'::public.category_type),
      ('Groceries', 'expense'),
      ('Transport', 'expense'),
      ('Housing', 'expense'),
      ('Utilities', 'expense'),
      ('Health', 'expense'),
      ('Education', 'expense'),
      ('Entertainment', 'expense'),
      ('Clothing', 'expense'),
      ('Other expenses', 'expense'),
      ('Salary', 'income'),
      ('Extra income', 'income'),
      ('Other income', 'income')
    ) as c (name, type);
  else
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
  end if;

  return new;
end;
$$;
