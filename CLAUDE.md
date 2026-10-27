# CLAUDE.md

Nutrition tracking PWA (Vue 3 + Vite + Tailwind v4 + Pinia + Supabase). Read [CONTEXT.md](CONTEXT.md)
for the schema, screens, and behaviour spec — keep it up to date when behaviour or schema changes.

## Commands
- `npm run dev` — dev server on :5173
- `npm run build` — production build (the only automated check; there are no tests or linter)

## Deployment caveats
- Pushing to `main` deploys straight to production on Vercel. Don't push without the user's go-ahead.
- No backend: the client talks to Supabase directly with the anon key, so all access control is RLS.
  Any new table needs RLS policies.
- Schema changes are run by hand in the Supabase SQL editor. Add each one as a numbered
  `supabase/migration_NNN_*.sql` file.
- **Known gap:** migrations 004b, 007, 008, 009 and the `search_ingredients` / `search_recipes`
  RPC functions (accent-insensitive search) exist in the live database but not in this repo.

## Conventions
- UI language is Greek; locale `el-GR`. Dates `dd/mm/yyyy`, times 24h (`hour12: false`).
- Timestamps are stored as UTC. User-entered times are built with local `setHours()` then `toISOString()`.
- `meal_log` rows snapshot macros at log time; either `recipe_id` or `ingredient_id` is set, never both.
- kcal per gram: protein 4, carbs 4, fat 9.
- Views use `<script setup>` and Tailwind utility classes inline; `@` aliases `src/`.

## Secrets
`.env` and `supabase.txt` hold credentials and are gitignored. Never read them into output or commit them.
