# 💰 mi-plata

**mi-plata** es una app de finanzas personales para el celular. Sirve para saber cuánto dinero tienes y dónde está, anotar lo que ganas y lo que gastas, llevar tus deudas y tus tarjetas de crédito, y ahorrar para lo que quieres.

Nació para reemplazar el registro manual de gastos y saldos en un chat de WhatsApp por una herramienta ordenada. Está en español e inglés y usa tu propia base de datos: tus datos son tuyos.

> **Estado:** versión 0.5.0, de uso personal. Funciona en escritorio Linux y compila para Android; la instalación en un teléfono real se explica más abajo. El código, la base de datos y la documentación son públicos para que cualquiera pueda leerlos, usarlos como ejemplo o montar su propia copia.

---

## ✨ Qué puedes hacer hoy

**Tu dinero**
- **Cuentas** de banco, efectivo, billeteras digitales y tarjetas de crédito, cada una con su moneda. El panel de inicio muestra tu **dinero total** (con lo que entró y salió este mes) y el saldo de cada cuenta.
- **Movimientos**: ingresos, gastos y transferencias entre cuentas. Se pueden buscar por texto y filtrar por tipo, cuenta, categoría y fechas. Las categorías son tuyas: crearlas, renombrarlas y archivarlas.
- **Varias monedas**: eliges una moneda base; todo se suma en ella y las transferencias entre monedas dicen cuánto sale y cuánto llega. Las **tasas de cambio se actualizan solas** una vez al día, y si prefieres puedes fijar una a mano.
- **Avisos que no estorban**: si un gasto deja una cuenta en negativo, la app avisa antes de guardar, pero te deja seguir.

**Entender en qué se va la plata**
- **Resumen mensual** con gráficos de ingresos contra gastos y por categoría, comparado con el mes anterior, el ritmo de gasto con su proyección a fin de mes y la evolución de tu dinero total.
- **Presupuestos** por categoría: cuánto quieres gastar al mes y cómo vas (bien, cerca del límite o pasado). La app avisa al registrar un gasto que lo acerca o lo supera.

**Lo que debes y lo que te deben**
- **Deudas** con abonos: cada abono es un movimiento real. También **compras a cuotas** con su plan de pagos.
- **Pagos recurrentes** (suscripciones, arriendo): la app avisa cuando se acerca la fecha, pero **nunca descuenta nada sola**: tú confirmas que pagaste.

**Tarjetas de crédito**
- Guardas el **cupo**, el **día de corte** y el **día de pago**. Ves cuánto has usado, cuánto te queda y las fechas, con avisos al llegar al 80 % o pasarte.
- Lo que gastas con la tarjeta **no resta de tu dinero total** hasta que la pagas; lo que debes aparece aparte.
- La app calcula **cuánto falta pagar de tu último corte**, avisa cuando se acerca o se pasó la fecha, y el botón *Pagar* abre la transferencia ya llenada.
- **Compras diferidas a cuotas**, con o sin intereses. Ver [Tarjetas de crédito](#-tarjetas-de-crédito).

**Ahorrar**
- **Metas de ahorro** con monto objetivo y fecha límite: cada meta se apoya en una cuenta, y la app sugiere cuánto ahorrar al mes para llegar a tiempo.

**La app en sí**
- Español e inglés (sigue el idioma del teléfono) y tema claro u oscuro: en Ajustes eliges entre claro, oscuro o el del teléfono, y el cambio se aplica al instante y se recuerda. Diseño pensado para pantallas pequeñas.
- Tu sesión es privada: cada usuario solo ve sus propios datos.

**Lo que todavía no hace:** funcionar sin internet, mandar notificaciones fuera de la app, importar extractos bancarios ni tener versión web. Son las ideas que siguen en la lista de [Futuro](#futuro).

---

## 🧩 Cómo funciona

```
   Tu teléfono                         Internet                       Supabase (tu proyecto)
┌───────────────┐   registra/consulta   ┌────────────────────────┐    ┌──────────────────────┐
│  App mi-plata │ ───────────────────▶  │  API segura (HTTPS)    │ ─▶ │  Base de datos       │
│   (Flutter)   │ ◀───────────────────  │  + inicio de sesión    │ ◀─ │  PostgreSQL + reglas │
└───────────────┘   solo tus datos      └────────────────────────┘    └──────────────────────┘
```

- **La app** (carpeta `app/`) está hecha con Flutter, así que es una sola base de código para Android y escritorio. Solo muestra datos y los envía; no guarda dinero en el teléfono.
- **La base de datos** (carpeta `supabase/`) es PostgreSQL, alojada en Supabase (o en tu computador, para desarrollar). Ahí viven tus cuentas y movimientos, y se hacen los cálculos delicados.
- **Los saldos no se guardan: se calculan** sumando tus movimientos. Por eso nunca se desajustan.
- **Tu privacidad la garantiza la base de datos**, no la app: cada fila lleva tu usuario y unas reglas (Row Level Security) impiden que alguien lea o cambie filas ajenas, aunque conozca la dirección del servidor.
- **La llave que lleva la app es pública por diseño** (la *publishable key*) y sin sesión no abre nada. La llave secreta nunca va en la app ni en el repositorio.
- **Cada cambio de la base de datos es una migración** (`supabase/migrations/`), así cualquiera puede recrear exactamente el mismo esquema.

---

### Futuro
- [ ] Modo sin conexión (primero consulta, luego registrar movimientos con cola de sincronización)
- [ ] Importación de extractos bancarios (CSV)
- [ ] Notificaciones de pagos próximos
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

## 🗄️ Modelo de datos

| Tabla | Descripción |
|---|---|
| `accounts` | Dónde está el dinero: nombre, tipo, saldo inicial, moneda (`COP` por defecto); en una tarjeta, también el cupo (`credit_limit`) y el día de corte y de pago (`statement_day`, `payment_day`) |
| `categories` | Clasificación de movimientos, de tipo ingreso (`income`) o gasto (`expense`) |
| `transactions` | Ingresos, gastos y transferencias (`income`, `expense`, `transfer`) asociados a una cuenta; en una transferencia entre monedas, `destination_amount` es lo que llega; `recurring_payment_id` dice de qué pago recurrente viene |
| `v_account_balances` | Vista que calcula el saldo actual de cada cuenta (y trae el cupo y los días de una tarjeta) |
| `debts` | Lo que debo (`payable`) o me deben (`receivable`): persona, monto, fechas y notas |
| `debt_payments` | Enlaza cada deuda con los movimientos que son sus abonos |
| `v_debt_balances` | Vista con lo pagado y lo pendiente de cada deuda |
| `v_monthly_totals` | Vista con ingresos y gastos por mes, tipo, categoría y moneda (para el resumen) |
| `v_monthly_account_flows` | Vista con lo que entró y salió de cada cuenta cada mes; con el saldo inicial reconstruye el dinero al cierre de cualquier mes |
| `user_settings` | Preferencias del usuario: la moneda base (`COP` por defecto, también si no hay fila) |
| `exchange_rates` | Cuánto vale 1 unidad de cada moneda en la moneda base; una tasa por moneda, sin historial. `is_manual` dice si la escribió el usuario (manual, no se pisa) o la trajo el servicio de tasas (automática) |
| `recurring_payments` | Una regla de pago recurrente: nombre, monto, cuenta, categoría, cada cuánto (`every` + `unit`), próxima fecha, fecha final y pausa. No genera movimientos sola. Con `debt_id` es el plan de cuotas de una deuda |
| `v_recurring_payments` | Vista con los pagos recurrentes más lo que falta de la deuda de un plan de cuotas y cuántas cuotas lleva pagadas |
| `budgets` | Presupuesto mensual de una categoría de gasto, vigente desde un mes (monto 0 = sin presupuesto); solo se aceptan categorías de gasto |
| `card_installment_plans` | Una compra con tarjeta diferida en cuotas: el gasto al que pertenece, lo que costaba sin intereses, cuántas cuotas y de cuánto cada una |
| `v_card_installment_plans` | Vista con cada plan y los datos de su gasto (tarjeta, fecha, descripción, total) |

Crear una deuda y registrar un abono son funciones de Postgres (`create_debt`, `register_debt_payment`) que se ejecutan completas o no se ejecutan: nunca queda dinero movido sin que la deuda lo sepa. Lo mismo vale para `set_exchange_rate` y `set_base_currency`, que reexpresa las tasas y los presupuestos al cambiar la moneda base, y para `confirm_recurring_payment`, `skip_recurring_payment`, `create_installment_debt` y `create_card_installment_purchase`.

**Principios de diseño:**

- Los montos se guardan como `numeric(14,2)`, nunca como `float`.
- Los saldos **se calculan** a partir de los movimientos; no se almacenan.
- Un saldo puede ser negativo (sobregiro, tarjetas), así que la base de datos no lo impide; en cambio la app **avisa antes de guardar** un movimiento que deje una cuenta en negativo. Las tarjetas quedan exentas de ese aviso (para ellas el negativo es lo normal), pero se avisa si un gasto las deja por encima de su cupo. Las tarjetas no cuentan en el dinero total.
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
git clone https://github.com/GooIvan/mi-plata.git
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

### Instalar en un teléfono Android (sin cable)

Necesitas tu propio proyecto de Supabase (gratis), no el de nadie más:

1. Crea el proyecto en supabase.com (Postgres estándar) y, en *Authentication → Sign In / Providers → Email*, apaga **Confirm email** si es solo para ti.
2. Sube el esquema: `supabase login`, `supabase link --project-ref <id>` y `supabase db push`.
3. Pon en `app/.env` la URL del proyecto y su *publishable key* (la que empieza con `sb_publishable_`). **Ese archivo se empaqueta dentro del APK**, por eso solo lleva la llave pública.
4. Compila: `cd app && flutter build apk --release`. El archivo queda en `app/build/app/outputs/flutter-apk/app-release.apk`.
5. Pásalo al teléfono (cable, Drive, Telegram…), ábrelo y permite instalar apps de origen desconocido. Se firma con la llave de depuración: sirve para uso personal, no para publicarlo en una tienda.

> ⚠️ No instales en tu teléfono un APK compilado por otra persona con *su* proyecto: tus datos irían a su servidor. Compila el tuyo.

### 5. Pruebas

```bash
cd app
flutter test                                                  # rápidas, sin red
flutter test test/integration --dart-define=INTEGRATION=true  # contra Supabase local
```

Las de integración necesitan `supabase start` y **solo corren contra Supabase local**: si el `.env` apunta a otro servidor, fallan antes de crear nada. Cada archivo borra al terminar los usuarios de prueba que creó (con todo lo suyo). Si una corrida se interrumpe quedan algunos; `scripts/limpiar-usuarios-de-prueba.sh` borra los de la base local (los que tienen correo `@example.com`) sin tocar tus datos, y conviene correrlo antes de abrir un pull request.

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

## 💳 Tarjetas de crédito

Una tarjeta es una cuenta de tipo *Tarjeta*. Su saldo es negativo cuando debes: lo **usado** es ese valor sin el signo, y lo **disponible**, el cupo menos lo usado. Nada de eso se guarda: se calcula, como el resto de los saldos.

- **Datos** (al crear o editar la tarjeta, todos opcionales): el **cupo**, el **día de corte** (cuando cierra el extracto) y el **día límite de pago**. Los dos días van juntos. Un día que el mes no tiene (un corte "31" en abril) cae en el último día del mes. Si el día de pago es menor o igual al de corte, se paga el mes siguiente.
- **No resta del dinero total.** Gastar con la tarjeta no baja el dinero total ni su evolución mensual: ese dinero sigue en tus cuentas hasta que pagas la tarjeta, y entonces sí sale. Lo que debes en tarjetas se ve aparte en la tarjeta principal del Inicio ("Debes en tarjetas"), sumado por tarjeta (el saldo a favor de una no paga la deuda de otra). Una tarjeta con saldo a favor no suma al total.
- **Cupo**: la barra pasa a ámbar desde el 80 % y a rojo al pasarte, siempre con ícono y texto. Al registrar un gasto que deja la tarjeta por encima de su cupo la app **avisa, sin bloquear** (el banco puede dejar pasar un poco).
- **Extracto**: con el día de corte, la app calcula lo que **falta pagar de tu último corte**: lo que debes hoy menos lo que se movió después del corte (compras y adelantos, que son del próximo extracto). Los pagos y reembolsos posteriores al corte lo bajan, como en el banco; si pagas de más, lo que sobra queda a favor para el siguiente. No hay extractos guardados ni historial, y es una guía: el extracto del banco manda.
- **Pagar la tarjeta** es una transferencia (no cuenta como gasto). *Pagar*, en la tarjeta y en el aviso de Inicio, abre el formulario con la tarjeta de destino, el monto que falta y como origen la cuenta con más dinero de la misma moneda (puedes cambiarla). **Pagos de tarjetas**, en Inicio, lista las que tienen algo por pagar, la más urgente primero; una fecha pasada se marca como vencida.

### Compras diferidas a cuotas

En el formulario de un gasto nuevo con tarjeta, **Diferir en cuotas** pide el número de cuotas (de 2 a 60) y, si el banco cobra intereses, el **valor de cada cuota**. Antes de guardar se ve el total y los intereses; sin valor de cuota no hay intereses y la compra se parte en partes iguales (la última absorbe los centavos).

- Se registra **un solo gasto por lo que se paga en total** (la compra más los intereses): la deuda y el cupo usado son los reales desde el primer día, y en el resumen del mes el gasto cae en el mes de la compra. Es un plan aparte (`card_installment_plans`), pero no se guarda nada por cuota.
- Al **extracto** solo entra una cuota por corte: la primera, en el primer corte desde la fecha de la compra (el mismo día del corte entra en ese corte). Lo que falta por cobrar no se debe todavía, así que no suma a lo que falta pagar del extracto.
- **Cuentas → Compras en cuotas (N)** lista las que siguen cobrándose: cuántas cuotas ya se cobraron, lo que falta y el corte de la próxima. Las ya cobradas completas dejan de aparecer; en la actividad, el movimiento dice "N cuotas".
- **Editar** una compra diferida no cambia su monto, su tarjeta ni su tipo (dejaría de cuadrar con las cuotas; la base de datos lo impide): descripción, categoría y fecha sí. Para cambiar el monto, se borra y se registra de nuevo. Borrarla borra también su plan.
- Las cuotas que escribes no pueden sumar menos que la compra (salvo los centavos del redondeo).
- **Límites conocidos**: la app no calcula intereses (los pones tú, como los cobra el banco); el cupo usado cuenta el total con intereses desde el principio, un poco más de lo que cuenta el banco; las fechas de cobro salen de los días de corte de hoy (si cambias el día de corte, se recalculan); una compra ya registrada no se puede convertir a cuotas; todavía no hay notificaciones fuera de la app.

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
- **Tasas de cambio** (Ajustes → Tasas de cambio): una por moneda ("1 USD vale $4.000"), con la fecha en que se actualizó y si es **automática** o **manual**.
  - **Automáticas**: al abrir la app, y como mucho una vez al día, se traen de [ExchangeRate-API](https://www.exchangerate-api.com) (versión abierta, sin llave; el servicio actualiza sus datos una vez al día, así que no son tasas al segundo). Se actualizan las monedas que usas en cuentas o deudas. El botón de actualizar de esa pantalla las trae en el momento.
  - **Manuales**: si escribes una tasa tú, queda como manual y **ninguna actualización la cambia**. Puedes devolverla a automática desde su formulario.
  - Si el servicio falla o no hay internet, se siguen usando las últimas tasas guardadas y la app lo dice al actualizar a mano; **nunca inventa un valor**. Una moneda sin tasa no se suma y la app lo avisa con un atajo para definirla.
  - La app no lleva ninguna llave del servicio. Si algún día se cambia a un proveedor que la exija, la consulta tendría que hacerse desde una función de Supabase, no desde la app.
- **Cambiar la base** reexpresa las tasas y los presupuestos en la moneda nueva; pide la tasa de la nueva si hay algo que convertir.
- **Transferencias entre monedas** guardan dos montos (`amount` sale, `destination_amount` llega) y muestran la tasa que resulta. Entre cuentas de la misma moneda no hay segundo monto.
- Los totales usan **la tasa de hoy**, también para meses pasados (no hay tasas históricas). Un movimiento siempre se ve en la moneda de su cuenta.
- **Límites conocidos**: un abono tiene que salir de una cuenta en la moneda de la deuda, y los presupuestos están en la moneda base (un gasto en otra moneda cuenta con la tasa de hoy).

---

## 📌 Convenciones

- **Commits**: [Conventional Commits](https://www.conventionalcommits.org/es/) (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`).
- **Ramas**: `main` estable; nuevas funcionalidades en `feat/<nombre>`.
- **Idioma**: el código, las tablas y las columnas van en inglés. Los textos que ve el usuario nunca se escriben en el código: van en `app/lib/l10n/*.arb`, uno por idioma.
- **Colores**: las pantallas no usan colores sueltos: salen del tema (`Theme.of(context).colorScheme` y `context.finance`).
- **Base de datos**: todo cambio de esquema se hace mediante una migración en `supabase/migrations/`, nunca a mano desde el panel.

---

## 📄 Licencia

Proyecto de uso personal. Todos los derechos reservados.
