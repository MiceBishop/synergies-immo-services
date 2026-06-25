# Synergies Immo Service — Claude Code Context

## What this is

Supabase project for the Synergies Immo property management back-office.
Declarative database schemas + Edge Functions.

Companion frontend repo: [synergies-immo-backoffice](https://github.com/MiceBishop/synergies-immo-backoffice).

## Stack

- Supabase (Postgres + Auth + Storage + Edge Functions)
- Declarative schemas in `supabase/schemas/`
- Versioned migrations in `supabase/migrations/`
- Edge Functions in `supabase/functions/` (Deno runtime, TypeScript)

## Declarative schema workflow

1. Edit a file in `supabase/schemas/` (one file per table, numbered for FK order).
2. Generate the incremental migration: `npm run diff <migration_name>`.
3. Review the generated SQL in `supabase/migrations/`.
4. Apply locally: `npm run migrate:up`.
5. Regenerate types for the backoffice: `npm run gen:types`.
6. Deploy: `npm run db:push`.

Explicit schema ordering lives in `supabase/config.toml` under `[db.migrations] schema_paths`.

## What goes in versioned migrations (NOT schema files)

`migra` (the diff engine) cannot reliably track:

- DML (`insert`, `update`, `delete`) — seed data
- RLS policies
- View ownership and grants
- Column privileges

Put these directly in `supabase/migrations/` as hand-written SQL.

## Language convention

- ALL SQL IN ENGLISH: table names, column names, enum values, function names, view names, comments
- User-facing French strings live in the backoffice repo, never here

## Key rules

- Always append new columns to the END of table definitions (migra ordering)
- Generated columns (e.g. `vat_amount`, `rent_incl_tax` on `leases`) are computed — never set directly
- Settings table is key-value config, NOT hardcoded constants. Read currency/VAT from there.
- `rent_dues` are pre-generated monthly, not computed on the fly
- Each `rent_due` can have 0-N payments (partial payment support)
- Use `date-fns` (in Edge Functions) for date handling — never raw `Date` arithmetic
- Never use the legacy `anon` / `service_role` keys — use the new publishable / secret keys

## Edge Functions

- TypeScript on Deno runtime
- Read settings from DB for currency/VAT config
- Notification router (`send-notification`): email (Resend), SMS (Twilio / Orange), WhatsApp (Twilio)

## Repo layout

```
supabase/
├── config.toml           ← schema_paths ordering
├── schemas/              ← declarative schema, one file per table (numbered)
├── migrations/           ← generated + hand-written migrations
├── functions/            ← Edge Functions
└── seed.sql              ← local seed (not used in prod)
```

## Linking to the remote Supabase project

Project ref: `mvqfqifshnlfzneyftnz` (<https://supabase.com/dashboard/project/mvqfqifshnlfzneyftnz>).

```bash
supabase login                                       # one-time
supabase link --project-ref mvqfqifshnlfzneyftnz     # one-time per checkout
supabase db push                                     # apply local migrations to remote
```

`supabase link` stores credentials in `.supabase/` (gitignored). Never commit them.

## See also

- `../IMPLEMENTATION_PLAN.md` — full plan
- `../RULES.md` — project rules
- `../MEMORY.md` — project memory
