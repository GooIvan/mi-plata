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
- [ ] **Soporte multimoneda**: moneda base, tasas de cambio y totales convertidos.
- [ ] **Gastos recurrentes** (suscripciones, arriendo), generados por el servidor sin duplicarse.
- [ ] **Metas de ahorro** con monto objetivo, fecha límite y progreso.

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
| `transactions` | Ingresos, gastos y transferencias (`income`, `expense`, `transfer`) asociados a una cuenta |
| `v_account_balances` | Vista que calcula el saldo actual de cada cuenta |
| `debts` | Lo que debo (`payable`) o me deben (`receivable`): persona, monto, fechas y notas |
| `debt_payments` | Enlaza cada deuda con los movimientos que son sus abonos |
| `v_debt_balances` | Vista con lo pagado y lo pendiente de cada deuda |
| `v_monthly_totals` | Vista con ingresos y gastos por mes, tipo, categoría y moneda (para el resumen) |
| `v_monthly_account_flows` | Vista con lo que entró y salió de cada cuenta cada mes; con el saldo inicial reconstruye el dinero al cierre de cualquier mes |
| `budgets` | Presupuesto mensual de una categoría de gasto, vigente desde un mes (monto 0 = sin presupuesto); solo se aceptan categorías de gasto |

Crear una deuda y registrar un abono son funciones de Postgres (`create_debt`, `register_debt_payment`) que se ejecutan completas o no se ejecutan: nunca queda dinero movido sin que la deuda lo sepa.

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

## 🌐 Idiomas

La app está en español e inglés. Los textos viven en `app/lib/l10n/app_es.arb` (plantilla) y `app_en.arb`; las clases que los usan las genera `flutter gen-l10n` (dentro de `app/`) y se guardan en el repositorio.

- **Agregar o cambiar un texto**: se edita en los dos `.arb` y se corre `flutter gen-l10n`. Una prueba falla si a un idioma le falta una clave, usa otros `{placeholders}` o si las clases generadas quedaron desactualizadas.
- **Montos y fechas** (`$1.500.000` / `$1,500,000`, `Lunes 12 de octubre` / `Monday, October 12`) salen de `core/format/formats.dart`; los campos de monto aceptan el formato del idioma activo.
- **Errores de la base de datos**: las validaciones de Postgres mandan un código estable en `detail` (por ejemplo `payment_exceeds_remaining`) y la app lo traduce con `core/errors/database_error.dart`. El mensaje en español se conserva como respaldo.
- **Categorías por defecto**: el idioma viaja en los metadatos del registro (`language`) y la base crea las 13 categorías en ese idioma. Lo que cada usuario escribe (nombres, descripciones) no se traduce.
- **Agregar un idioma**: un `app_xx.arb` nuevo, el código en `supportedLanguages` (`core/l10n/locale_controller.dart`), su opción en Ajustes, sus formatos en `Formats` y sus categorías en `create_default_categories()` (una migración nueva).

---

## 📌 Convenciones

- **Commits**: [Conventional Commits](https://www.conventionalcommits.org/es/) (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`).
- **Ramas**: `main` estable; nuevas funcionalidades en `feat/<nombre>`.
- **Idioma**: el código, las tablas y las columnas van en inglés. Los textos que ve el usuario nunca se escriben en el código: van en `app/lib/l10n/*.arb`, uno por idioma.
- **Base de datos**: todo cambio de esquema se hace mediante una migración en `supabase/migrations/`, nunca a mano desde el panel.

---

## 📄 Licencia

Proyecto de uso personal. Todos los derechos reservados.
