-- Que cada usuario pueda borrar su propia cuenta y todo lo suyo.
--
-- Borrar la fila de auth.users arrastra, por las claves foráneas en cascada,
-- todo lo que le pertenece: cuentas, movimientos, categorías, deudas,
-- presupuestos, recurrentes, metas, tasas, tarjetas, perfil y sesiones. No se
-- puede deshacer.
--
-- Solo puede borrar la suya: la función usa auth.uid(), no recibe un id.
-- Es SECURITY DEFINER porque el usuario no tiene permiso sobre auth.users.

create function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Necesitas iniciar sesión' using errcode = '28000';
  end if;

  delete from auth.users where id = auth.uid();
end;
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
