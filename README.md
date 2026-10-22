# 💰 mi-plata

Aplicación móvil de finanzas personales para llevar el control del dinero en todas mis cuentas, registrar ingresos y gastos, gestionar deudas y avanzar hacia metas de ahorro.

Nace para reemplazar el registro manual de gastos y saldos en un chat de WhatsApp por una herramienta ordenada, con base de datos propia y lista para crecer.

---

## ✨ Funcionalidades

### Fase 1 — Núcleo
- [x] **Autenticación**: registro e inicio de sesión con correo y contraseña.
- [ ] **Panel general**: saldo total consolidado y saldo por cuenta.
- [ ] **Cuentas**: bancos, efectivo, billeteras digitales y tarjetas.
- [ ] **Categorías** de ingresos y gastos, personalizables.
- [ ] **Movimientos**: ingresos, gastos y transferencias entre cuentas.

### Fase 2 — Análisis y deudas
- [ ] **Resumen mensual**: ingresos vs. gastos y distribución por categoría con gráficos.
- [ ] **Deudas**: lo que debo y lo que me deben, con registro de abonos.

### Fase 3 — Ahorro
- [ ] **Metas de ahorro** con monto objetivo, fecha límite y progreso.

### Futuro
- [ ] Presupuestos por categoría
- [ ] Gastos recurrentes (suscripciones, arriendo)
- [ ] Importación de extractos bancarios (CSV)
- [ ] Soporte multimoneda
- [ ] Modo sin conexión
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

**Principios de diseño:**

- Los montos se guardan como `numeric(14,2)`, nunca como `float`.
- Los saldos **se calculan** a partir de los movimientos; no se almacenan.
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

Para desarrollo local, `supabase status` muestra la URL y la publishable key. Desde el emulador de Android, `localhost` del equipo es `10.0.2.2`.

> ⚠️ El archivo `.env` está en `.gitignore`. Nunca subas tus llaves al repositorio y jamás uses la `secret key` (antes `service_role`) dentro de la app.

### 4. Ejecutar la app

```bash
cd app
flutter pub get
flutter run
```

---

## 📌 Convenciones

- **Commits**: [Conventional Commits](https://www.conventionalcommits.org/es/) (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`).
- **Ramas**: `main` estable; nuevas funcionalidades en `feat/<nombre>`.
- **Idioma**: el código, las tablas y las columnas van en inglés; los textos que ve el usuario (interfaz, mensajes, categorías por defecto), en español.
- **Base de datos**: todo cambio de esquema se hace mediante una migración en `supabase/migrations/`, nunca a mano desde el panel.

---

## 📄 Licencia

Proyecto de uso personal. Todos los derechos reservados.
