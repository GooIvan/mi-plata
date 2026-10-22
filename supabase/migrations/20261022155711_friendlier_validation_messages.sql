-- Los mensajes de validación llegan al usuario tal cual: no deben mostrar
-- los nombres internos de los tipos (income, expense...).

create or replace function public.validate_transaction()
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
      raise exception 'La categoría elegida no corresponde a este tipo de movimiento'
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
