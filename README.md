# Synergies Immo — Services

Supabase backend for the Synergies Immo property management back-office.
Declarative schemas, versioned migrations, Edge Functions.

Companion frontend: [synergies-immo-backoffice](https://github.com/MiceBishop/synergies-immo-backoffice).

## Requirements

- [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started) (`brew install supabase/tap/supabase`)
- Docker (for `supabase start`)
- Node.js 20+

## Quick start

```bash
npm run start        # boot local Supabase stack
npm run status       # show local URLs and keys
npm run migrate:up   # apply migrations
npm run gen:types    # regenerate TS types for the backoffice
```

## Declarative schema workflow

1. Edit a file in `supabase/schemas/`.
2. `npm run diff <migration_name>` to generate the migration.
3. Review the migration in `supabase/migrations/`.
4. `npm run migrate:up` to apply locally.
5. `npm run db:push` to deploy.

See `CLAUDE.md` for the full convention.
