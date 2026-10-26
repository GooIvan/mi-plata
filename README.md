# 💰 mi-plata

Aplicación móvil de finanzas personales para llevar el control del dinero en todas mis cuentas, registrar ingresos y gastos, gestionar deudas y avanzar hacia metas de ahorro.

Nace para reemplazar el registro manual de gastos y saldos en un chat de WhatsApp por una herramienta ordenada, con base de datos propia y lista para crecer.

---

## ✨ Funcionalidades

### Fase 1 — Núcleo
- [x] **Autenticación**: registro e inicio de sesión con correo y contraseña.
- [x] **Panel general**: saldo total consolidado y saldo por cuenta.
- [x] **Cuentas**: bancos, efectivo, billeteras digitales y tarjetas.
- [x] **Categorías** de ingresos y gastos, personalizables: crear, renombrar y archivar (cada usuario empieza con 13 por defecto).
- [x] **Movimientos**: ingresos, gastos y transferencias entre cuentas. Se pueden buscar por texto y filtrar por tipo, cuenta, categoría y fechas; la lista carga por páginas.

### Fase 2 — Análisis, deudas y presupuestos
- [x] **Resumen mensual**: ingresos vs. gastos y distribución por categoría con gráficos. Las transferencias no cuentan como ingreso ni gasto. Compara cada cifra y cada categoría con el mes anterior, muestra el ritmo de gasto con su proyección a fin de mes y la evolución del dinero total mes a mes.
- [x] **Deudas**: lo que debo y lo que me deben, con registro de abonos. Cada abono es un movimiento real (gasto si debo, ingreso si me deben) y el préstamo inicial se puede registrar opcionalmente en una cuenta.
- [x] **Presupuestos por categoría**: cuánto quiero gastar al mes en cada categoría de gasto y cómo voy (bien, cerca del límite desde el 80 %, o pasado). Un presupuesto rige desde el mes en que se define hasta que se cambie, así que subirlo no reescribe los meses anteriores, que solo se consultan. Aparece en el panel y avisa, sin bloquear, al registrar un gasto que llega al 80 % o supera el presupuesto.

### Fase 3 — Idiomas, monedas, recurrentes y ahorro
- [x] **Internacionalización**: español e inglés. La app sigue el idioma del teléfono (español si no lo tiene) y se puede cambiar en Ajustes. Montos, fechas, errores de la base de datos y categorías por defecto también se adaptan (ver [Idiomas](#-idiomas)).
- [x] **Soporte multimoneda**: cada cuenta tiene su moneda; todo se suma en una moneda base con tasas de cambio que defines tú, y las transferencias entre monedas dicen cuánto sale y cuánto llega (ver [Monedas](#-monedas)).
- [x] **Pagos recurrentes** (suscripciones, arriendo): se registra qué se paga, cuánto y cada cuánto; cuando se acerca la fecha la app avisa con "Pago próximo" y **no descuenta nada hasta que confirmas que pagaste** (o lo omites). Ver [Pagos recurrentes](#-pagos-recurrentes).
- [x] **Metas de ahorro** con monto objetivo, fecha límite y progreso: cada meta se apoya en una cuenta y lo ahorrado es el saldo de esa cuenta. Ver [Metas de ahorro](#-metas-de-ahorro).

### Futuro
- [ ] Modo sin conexión (primero consulta, luego registrar movimientos con cola de sincronización)
- [ ] Importación de extractos bancarios (CSV)
- [ ] Versión web (Flutter Web)

---

## 🛠️ Stack tecnológico

| Capa | Tecnología |
|---|---|
| App móvil | [Flutter](https://flutter.dev) (Dart) |
| Gestión de estado | Riverpod |
| Backend / BaaS | [Supabase](https://supabase.com) |
| Base de datos | PostgreSQL |
| Autenticación | Supabase Auth |
| Migraciones | Supabase CLI |

---

## 📁 Estructura del repositorio

```
mi-plata/
├── app/                # Proyecto Flutter
│   └── lib/
│       ├── core/       # Configuración, tema, utilidades compartidas
│       └── features/   # Un módulo por funcionalidad
│           ├── auth/
│           ├── accounts/
│           ├── categories/
│           ├── transactions/
│           ├── summary/
│           ├── debts/
│           ├── budgets/
│           ├── currency/
│           ├── recurring/
│           ├── savings/
│           ├── settings/
│           └── dashboard/
├── supabase/           # Migraciones SQL, vistas y políticas de seguridad
│   └── migrations/
└── README.md
```

Cada módulo dentro de `features/` se organiza en capas:

- `data/` → modelos y repositorios (acceso a Supabase)
- `domain/` → entidades y lógica de negocio
- `presentation/` → pantallas, widgets y providers

---

## 🗄️ Modelo de datos (Fase 1)

| Tabla | Descripción |
|---|---|
| `accounts` | Dónde está el dinero: nombre, tipo, saldo inicial, moneda (`COP` por defecto) |
| `categories` | Clasificación de movimientos, de tipo ingreso (`income`) o gasto (`expense`) |
| `transactions` | Ingresos, gastos y transferencias (`income`, `expense`, `transfer`) asociados a una cuenta; en una transferencia entre monedas, `destination_amount` es lo que llega; `recurring_payment_id` dice de qué pago recurrente viene |
| `v_account_balances` | Vista que calcula el saldo actual de cada cuenta |
| `debts` | Lo que debo (`payable`) o me deben (`receivable`): persona, monto, fechas y notas |
| `debt_payments` | Enlaza cada deuda con los movimientos que son sus abonos |
| `v_debt_balances` | Vista con lo pagado y lo pendiente de cada deuda |
| `v_monthly_totals` | Vista con ingresos y gastos por mes, tipo, categoría y moneda (para el resumen) |
| `v_monthly_account_flows` | Vista con lo que entró y salió de cada cuenta cada mes; con el saldo inicial reconstruye el dinero al cierre de cualquier mes |
| `user_settings` | Preferencias del usuario: la moneda base (`COP` por defecto, también si no hay fila) |
| `exchange_rates` | Cuánto vale 1 unidad de cada moneda en la moneda base; una tasa por moneda, sin historial |
| `recurring_payments` | Una regla de pago recurrente: nombre, monto, cuenta, categoría, cada cuánto (`every` + `unit`), próxima fecha, fecha final y pausa. No genera movimientos sola. Con `debt_id` es el plan de cuotas de una deuda |
| `v_recurring_payments` | Vista con los pagos recurrentes más lo que falta de la deuda de un plan de cuotas y cuántas cuotas lleva pagadas |
| `budgets` | Presupuesto mensual de una categoría de gasto, vigente desde un mes (monto 0 = sin presupuesto); solo se aceptan categorías de gasto |

Crear una deuda y registrar un abono son funciones de Postgres (`create_debt`, `register_debt_payment`) que se ejecutan completas o no se ejecutan: nunca queda dinero movido sin que la deuda lo sepa. Lo mismo vale para `set_exchange_rate` y `set_base_currency`, que reexpresa las tasas y los presupuestos al cambiar la moneda base, y para `confirm_recurring_payment`, `skip_recurring_payment` y `create_installment_debt`.

**Principios de diseño:**

- Los montos se guardan como `numeric(14,2)`, nunca como `float`.
- Los saldos **se calculan** a partir de los movimientos; no se almacenan.
- Un saldo puede ser negativo (sobregiro, tarjetas), así que la base de datos no lo impide; en cambio la app **avisa antes de guardar** un movimiento que deje una cuenta en negativo. Las tarjetas quedan exentas.
- Las transferencias entre cuentas son una sola fila (`account_id` → `destination_account_id`) y no cuentan como gasto ni ingreso.
- Las cuentas y categorías se archivan en lugar de eliminarse, para conservar el historial.
- Todas las tablas incluyen `user_id` y están protegidas con Row Level Security (RLS).

---

## 🚀 Puesta en marcha

### Requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- [Supabase CLI](https://supabase.com/docs/guides/cli)
- Docker (opcional, para correr Supabase en local)
- Una cuenta en [Supabase](https://supabase.com)

### 1. Clonar el repositorio

```bash
git clone https://github.com/<tu-usuario>/mi-plata.git
cd mi-plata
```

### 2. Configurar la base de datos

```bash
supabase login
supabase link --project-ref <id-del-proyecto>
supabase db push
```

### 3. Configurar variables de entorno

Copiar `app/.env.example` a `app/.env` y completar los valores:

```env
SUPABASE_URL=https://<id-del-proyecto>.supabase.co
SUPABASE_PUBLISHABLE_KEY=<tu-publishable-key>
```

Para desarrollo local, `supabase status` muestra la URL y la publishable key. En Android (emulador o celular por USB) hay que ejecutar antes `adb reverse tcp:54321 tcp:54321` para que `127.0.0.1` llegue a tu equipo.

> ⚠️ El archivo `.env` está en `.gitignore`. Nunca subas tus llaves al repositorio y jamás uses la `secret key` (antes `service_role`) dentro de la app.

### 4. Ejecutar la app

```bash
supabase start          # base de datos local (desde la raíz del repositorio)
cd app
flutter pub get
flutter run -d linux    # escritorio: liviano, ideal para desarrollar la interfaz
```

Para probar en Android (emulador o celular por USB):

```bash
adb reverse tcp:54321 tcp:54321
flutter run
```

### 5. Pruebas

```bash
cd app
flutter test                                                  # rápidas, sin red
flutter test test/integration --dart-define=INTEGRATION=true  # contra Supabase local
```

Las de integración necesitan `supabase start` y crean usuarios de prueba que se borran con `supabase db reset`.

---

## 🔁 Pagos recurrentes

Para lo que pagas cada cierto tiempo: suscripciones, arriendo, seguros. Cada pago dice cuánto es, desde qué cuenta suele salir, de qué categoría y cada cuánto (cada semana, 2 semanas, mes, 2, 3 o 6 meses, año).

- **No descuenta nada solo.** La app guarda la fecha del próximo pago y, cuando falta una semana o menos, lo marca como **"Pago próximo"** (con ícono y texto, no solo color). Vencido se marca aparte.
- **Tú confirmas.** "Ya pagué" abre una hoja con el monto, la cuenta y la fecha ya listos (puedes cambiarlos: el precio pudo subir, o pagaste desde otra cuenta). Al confirmar se crea el gasto de verdad —con el aviso de saldo negativo y el de presupuesto de siempre— y el pago pasa a la fecha siguiente. "Omitir este pago" pasa a la siguiente fecha sin crear nada.
- **Las fechas**: un pago del 31 cae el último día de cada mes y vuelve al 31 (no se va corriendo hacia el 28). Un pago vencido varios meses se confirma u omite de a uno.
- **En el panel** salen los tres que más urgen, cada uno con su botón; en la lista (`Pagos recurrentes`) están todos, y los pausados o terminados al final. Se pueden pausar, editar, ponerles fecha final y eliminar (los gastos ya registrados se quedan).
- Borrar un gasto registrado desde un pago no devuelve el pago a su fecha anterior: si hace falta, se edita la fecha del próximo pago.
- Todavía no hay notificaciones fuera de la app.

### Compras a cuotas

Una compra que se paga de a poco (un televisor en 12 cuotas, un crédito de una tienda) es una **deuda con un plan de cuotas**. Se crea en Deudas → Nueva deuda ("Debo") con el interruptor **Pagar en cuotas**: el total que vas a pagar (con intereses, si los hay), cuántas cuotas, el valor de cada una, cada cuánto, la fecha de la primera y la cuenta de la que las pagas.

- El plan funciona como cualquier pago recurrente: avisa "Pago próximo" y tú confirmas. La diferencia es que confirmar **registra un abono a la deuda**, así que lo que falta por pagar va bajando y ves "Cuota 4 de 12".
- La última cuota propone solo lo que falte. Cuando la deuda queda saldada —también si la saldas con un abono suelto— el plan termina solo.
- Omitir una cuota no cambia lo que debes: el plan sigue hasta que se pague todo, aunque pase de las cuotas pactadas.
- La deuda es en la moneda de la cuenta con que se pagan las cuotas. Crear la compra no mueve dinero; cada abono es un gasto del mes en que lo pagas.
- Todavía solo sirve para deudas que *debes*, y no para préstamos en los que recibes el dinero (para esos, registra el préstamo como una deuda normal).

---

## 🎯 Metas de ahorro

Una meta es **una cantidad que quieres juntar en una cuenta**, con una fecha límite si quieres: un viaje, una moto, el fondo de emergencia.

- **Cada meta se apoya en una cuenta** (la creas ahí mismo o eliges una que ya tienes) y **lo ahorrado es el saldo de esa cuenta**. No hay un "avance" guardado aparte, así que el dinero nunca se cuenta dos veces: si pasas plata a esa cuenta la meta sube, si la sacas baja, y los totales del panel siguen siendo los de siempre.
- **Ahorrar es una transferencia.** En el detalle de la meta, *Ahorrar* abre el formulario de transferencia con la cuenta de la meta como destino, y *Sacar* con ella como origen. Si solo tienes otra cuenta, ya viene elegida.
- **Cómo va**: porcentaje (hacia abajo: no dice 100 % antes de llegar), lo que falta y los días que quedan. Una meta cumplida se marca ("¡Meta cumplida!") y una vencida sin cumplir dice cuánto faltó. Siempre con ícono y texto, no solo color.
- **Cuánto ahorrar**: con fecha, el detalle sugiere cuánto apartar al mes para llegar a tiempo (redondeado hacia arriba a la unidad entera, nunca más de lo que falta) o, si queda menos de un mes, todo lo que falta antes de la fecha.
- **Reglas**: una cuenta tiene **una sola meta activa** (dos metas sobre la misma cuenta serían el mismo dinero) y **una tarjeta no puede ser la cuenta de una meta**. La cuenta de una meta no se cambia después. El monto está en la moneda de la cuenta.
- **Archivar**: cuando ya no la necesites, archiva la meta; su cuenta queda libre para otra, y las archivadas se consultan con el botón de la lista. Un saldo negativo cuenta como cero ahorrado.
- **En el panel** salen las tres metas que vencen primero, con su barra de avance; la lista completa está en *Metas de ahorro*.

---

## 🌐 Idiomas

La app está en español e inglés. Los textos viven en `app/lib/l10n/app_es.arb` (plantilla) y `app_en.arb`; las clases que los usan las genera `flutter gen-l10n` (dentro de `app/`) y se guardan en el repositorio.

- **Agregar o cambiar un texto**: se edita en los dos `.arb` y se corre `flutter gen-l10n`. Una prueba falla si a un idioma le falta una clave, usa otros `{placeholders}` o si las clases generadas quedaron desactualizadas.
- **Montos y fechas** (`$1.500.000` / `$1,500,000`, `Lunes 12 de octubre` / `Monday, October 12`) salen de `core/format/formats.dart`; los campos de monto aceptan el formato del idioma activo.
- **Errores de la base de datos**: las validaciones de Postgres mandan un código estable en `detail` (por ejemplo `payment_exceeds_remaining`) y la app lo traduce con `core/errors/database_error.dart`. El mensaje en español se conserva como respaldo.
- **Categorías por defecto**: el idioma viaja en los metadatos del registro (`language`) y la base crea las 13 categorías en ese idioma. Lo que cada usuario escribe (nombres, descripciones) no se traduce.
- **Agregar un idioma**: un `app_xx.arb` nuevo, el código en `supportedLanguages` (`core/l10n/locale_controller.dart`), su opción en Ajustes, sus formatos en `Formats` y sus categorías en `create_default_categories()` (una migración nueva).

---

## 💱 Monedas

Cada cuenta (y cada deuda) tiene su moneda, que se elige al crearla y no cambia. Las monedas que ofrece la app son COP, USD, EUR, MXN, ARS, BRL, CLP, PEN, GBP y CAD (la base de datos acepta cualquier código de tres letras).

- **Moneda base** (Ajustes → Moneda): es en la que se suma todo — dinero total, resumen, evolución, presupuestos y deudas. Por defecto, el peso colombiano.
- **Tasas de cambio** (Ajustes → Tasas de cambio): las defines tú, una por moneda ("1 USD vale $4.000"), con la fecha en que las cambiaste. No dependen de ningún servicio externo. Una moneda sin tasa no se suma y la app lo avisa con un atajo para definirla; nunca inventa un valor.
- **Cambiar la base** reexpresa las tasas y los presupuestos en la moneda nueva; pide la tasa de la nueva si hay algo que convertir.
- **Transferencias entre monedas** guardan dos montos (`amount` sale, `destination_amount` llega) y muestran la tasa que resulta. Entre cuentas de la misma moneda no hay segundo monto.
- Los totales usan **la tasa de hoy**, también para meses pasados (no hay tasas históricas). Un movimiento siempre se ve en la moneda de su cuenta.
- **Límites conocidos**: un abono tiene que salir de una cuenta en la moneda de la deuda, y los presupuestos están en la moneda base (un gasto en otra moneda cuenta con la tasa de hoy).

---

## 📌 Convenciones

- **Commits**: [Conventional Commits](https://www.conventionalcommits.org/es/) (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`).
- **Ramas**: `main` estable; nuevas funcionalidades en `feat/<nombre>`.
- **Idioma**: el código, las tablas y las columnas van en inglés. Los textos que ve el usuario nunca se escriben en el código: van en `app/lib/l10n/*.arb`, uno por idioma.
- **Base de datos**: todo cambio de esquema se hace mediante una migración en `supabase/migrations/`, nunca a mano desde el panel.

---

## 📄 Licencia

Proyecto de uso personal. Todos los derechos reservados.
