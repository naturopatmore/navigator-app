# Workspace

## Overview

pnpm workspace monorepo using TypeScript. Each package manages its own dependencies.
This project contains «Навигатор здоровья» — a Russian-language health coaching web app for coach Sasha More and her clients.

## Stack

- **Monorepo tool**: pnpm workspaces
- **Node.js version**: 24
- **Package manager**: pnpm
- **TypeScript version**: 5.9
- **API framework**: Express 5
- **Database**: PostgreSQL + Drizzle ORM
- **Validation**: Zod (`zod/v4`), `drizzle-zod`
- **API codegen**: Orval (from OpenAPI spec)
- **Build**: esbuild (CJS bundle)
- **Frontend**: React + Vite, Tailwind CSS, Framer Motion, Zustand
- **Design**: Glassmorphism; Font: Manrope; Colors: bg #D9DCD6, primary #3A7CA5/#2F6690, dark #16425B, accent #81C3D7

## Structure

```text
artifacts-monorepo/
├── artifacts/              # Deployable applications
│   ├── api-server/         # Express API server
│   └── navigator/          # React Vite frontend (Навигатор здоровья)
├── lib/                    # Shared libraries
│   ├── api-spec/           # OpenAPI spec + Orval codegen config
│   ├── api-client-react/   # Generated React Query hooks
│   ├── api-zod/            # Generated Zod schemas from OpenAPI
│   └── db/                 # Drizzle ORM schema + DB connection
├── scripts/                # Utility scripts (single workspace package)
│   └── src/                # Individual .ts scripts, run via `pnpm --filter @workspace/scripts run <script>`
├── pnpm-workspace.yaml     # pnpm workspace (artifacts/*, lib/*, lib/integrations/*, scripts)
├── tsconfig.base.json      # Shared TS options (composite, bundler resolution, es2022)
├── tsconfig.json           # Root TS project references
└── package.json            # Root package with hoisted devDeps
```

## App Features

### «Навигатор здоровья» (Health Navigator)

A health coaching tracking app where coach "Сasha More" (Саша Море) manages clients.

**Login codes**: `ADMIN` (admin/coach), `ABC-12` (test client "Лена")

**Client experience** (login with unique code like `ABC-12`):
- **Обзор**: Dashboard — today's overview of meals, water, sleep, energy, skin condition
- **Запись**: Daily log entry form (meals, water/drinks, sleep quality, stool, energy, skin, victories, notes)
- **Замеры**: Body measurements (weight, waist, belly, hips, arms, legs) with history charts
- **Чат**: Real-time messaging with coach (24/7 in app, visible Mon & Fri 10:30-18:30 MSK)
- **Уроки**: Video lessons — YouTube/Vimeo embed or uploaded file, fullscreen modal player
- **Рецепты**: Recipe book (admin-managed)
- **Профиль**: Goals, notification settings, avatar upload, 45-question onboarding questionnaire, knowledge base, diary download
- **Нейронатуропат**: AI food compatibility assistant — "Анализ" tab (chat: describe meals → compatibility verdict) + "Копилка" tab (saved correct meals, PDF export)

**Admin experience** (login with code `ADMIN`):
- **Клиенты tab**: Client management (create, activate/deactivate), view client logs, measurements, and answers to questionnaire. Chat with each client, unread badges.
- **Рецепты tab**: Create, edit, delete recipe cards with ingredient lists and cooking instructions
- **Нейронатуропат tab**: Manage food compatibility lists — editable Белки (proteins) and Углеводы (carbs) lists; клетчатка is a fixed "pairs with both" UI card (not editable)
- **Уроки tab**: Create/edit/delete video lessons — supports YouTube/Vimeo URL or file upload, thumbnail upload, publish/draft toggle, fullscreen preview

**Smart health tips** (SashaTip component):
- Complex dishes detected → ingredient breakdown tip
- Late meals (after 18:00) → timing advice
- Water during/after meals → digestive tip
- Tea/coffee after meals → tip

## Database Schema

- `clients` — access codes, active status
- `logs` — daily diary entries (meals, water, sleep, stool, energy, skin, victory, notes) stored as JSONB
- `measurements` — body measurements (weight, waist, belly, hips, arms, legs)
- `profiles` — client goals and notification preferences
- `messages` — chat messages between coach and clients
- `recipes` — recipe cards with title, description, ingredients, steps
- `neuronath_foods` — food compatibility lists (proteins/carbs, type field)
- `neuronath_meals` — saved "correct meal" entries per client (for Копилка)
- `lessons` — video lessons (title, description, video_url, video_path, thumbnail_url, assigned_to JSON string[], is_published, created_at)
- `sections` — custom admin-created content sections (title, icon emoji, content text, sort_order, is_published, created_at); published sections appear in client "Разделы" tab
- `questionnaire_answers` — client onboarding questionnaire responses (45 questions)

## Key Technical Notes

- `BASE` = `import.meta.env.BASE_URL` (value: `/`) — always prefix API calls with BASE
- Object storage: `useUpload({ basePath: \`${BASE}api/storage\`, onSuccess: ({objectPath}) => ... })`; files served at `${BASE}api/storage/objects/${objectPath}`
- Нейронатуропат: Russian stemmer (`stem()` in neuronath.ts) handles inflections via 75% root matching (e.g. курицей→курица)
- DB push: `pnpm --filter @workspace/db run push`

## Seeded Data

- `ADMIN` client — admin login
- `ABC-12` client — test client "Лена"

## TypeScript & Composite Projects

Every package extends `tsconfig.base.json` which sets `composite: true`. The root `tsconfig.json` lists all packages as project references. This means:

- **Always typecheck from the root** — run `pnpm run typecheck` (which runs `tsc --build --emitDeclarationOnly`). This builds the full dependency graph so that cross-package imports resolve correctly. Running `tsc` inside a single package will fail if its dependencies haven't been built yet.
- **`emitDeclarationOnly`** — we only emit `.d.ts` files during typecheck; actual JS bundling is handled by esbuild/tsx/vite...etc, not `tsc`.
- **Project references** — when package A depends on package B, A's `tsconfig.json` must list B in its `references` array. `tsc --build` uses this to determine build order and skip up-to-date packages.

## Root Scripts

- `pnpm run build` — runs `typecheck` first, then recursively runs `build` in all packages that define it
- `pnpm run typecheck` — runs `tsc --build --emitDeclarationOnly` using project references

## Packages

### `artifacts/api-server` (`@workspace/api-server`)

Express 5 API server. Routes live in `src/routes/` and use `@workspace/api-zod` for request and response validation and `@workspace/db` for persistence.

Routes:
- `auth.ts` — POST /auth (login with code)
- `logs.ts` — GET/POST /logs/:clientCode/:date
- `measurements.ts` — GET/POST /measurements/:clientCode
- `profiles.ts` — GET/POST /profile/:clientCode
- `messages.ts` — GET/POST /messages/:clientCode, POST .../read, GET .../unread
- `admin.ts` — GET /admin/clients, POST /admin/clients, POST /admin/clients/:code/toggle, GET /admin/logs/:clientCode, GET /admin/unread
- `recipes.ts` — GET/POST/PUT/DELETE /recipes
- `neuronath.ts` — POST /neuronath/analyze, GET/POST/DELETE /neuronath/foods, GET/POST/DELETE /neuronath/meals
- `lessons.ts` — GET/POST /lessons, GET /lessons/:clientCode, PUT/DELETE /lessons/:id
- `questionnaire.ts` — GET/POST /questionnaire/:clientCode
- `storage.ts` — object storage (upload, serve files)

### `artifacts/navigator` (`@workspace/navigator`)

React + Vite frontend for Навигатор здоровья. Uses generated API hooks, Zustand for auth state, Framer Motion for animations, glass morphism UI design.

Pages:
- `pages/auth/Login.tsx` — code-based login
- `pages/client/` — Overview, Entry, Measurements, Chat, Lessons, Recipes, Profile
- `pages/client/Questionnaire.tsx` — 45-question onboarding form
- `pages/admin/AdminPanel.tsx` — 4-tab admin panel (Клиенты, Рецепты, Нейронатуропат, Уроки)
- `components/NeuronathPanel.tsx` — client Нейронатуропат widget (Анализ + Копилка tabs)
- `components/Layout.tsx` — bottom nav (7 tabs: Обзор, Запись, Замеры, Чат, Уроки, Рецепты, Профиль)

### `lib/db` (`@workspace/db`)

Database layer using Drizzle ORM with PostgreSQL. Exports a Drizzle client instance and schema models.

### `lib/api-spec` (`@workspace/api-spec`)

Owns the OpenAPI 3.1 spec (`openapi.yaml`) and the Orval config (`orval.config.ts`). Running codegen produces output into two sibling packages.

Run codegen: `pnpm --filter @workspace/api-spec run codegen`

### `lib/api-zod` (`@workspace/api-zod`)

Generated Zod schemas from the OpenAPI spec.

### `lib/api-client-react` (`@workspace/api-client-react`)

Generated React Query hooks and fetch client from the OpenAPI spec.
