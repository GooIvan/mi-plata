#!/usr/bin/env bash
# Borra de la base de datos LOCAL los usuarios que crean las pruebas de
# integración (correos @example.com) con todos sus datos. No toca otros usuarios
# ni el esquema. Las pruebas ya borran los suyos al terminar; esto sirve para lo
# que quede de una corrida interrumpida.
#
#   scripts/limpiar-usuarios-de-prueba.sh
set -euo pipefail

container="${SUPABASE_DB_CONTAINER:-supabase_db_mi-plata}"

if [ "$(docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null || true)" != "true" ]; then
  echo "No encuentro la base local ($container). ¿Corriste 'supabase start'?" >&2
  exit 1
fi

docker exec -i "$container" psql -U postgres -v ON_ERROR_STOP=1 -At <<'SQL'
with borrados as (
  delete from auth.users where email like '%@example.com' returning 1
)
select 'Usuarios de prueba borrados: ' || count(*) from borrados;
select 'Usuarios que quedan: ' || count(*) from auth.users;
SQL
