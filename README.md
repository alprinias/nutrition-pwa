# Διατροφή — Nutrition Tracker

A mobile-first PWA for logging meals, tracking daily calories and macros against personal targets,
and recording body measurements. It replaces a manually maintained Excel workbook
(`supabase/Διατροφή.xlsx`).

Live: https://nutrition-pwa-wheat.vercel.app

## Stack
Vue 3 + Vite · Tailwind CSS v4 · Pinia · Vue Router · vite-plugin-pwa · Supabase (Postgres, Auth, RLS) · Vercel

## Getting started
```bash
npm install
cp .env.example .env   # fill in your Supabase URL and anon key
npm run dev            # http://localhost:5173
```

| Script | Purpose |
|---|---|
| `npm run dev` | Dev server |
| `npm run build` | Production build to `dist/` |
| `npm run preview` | Serve the production build locally |

## Deployment
Pushing to `main` on GitHub triggers a Vercel deploy (~60s). The service worker uses
`skipWaiting` + `clientsClaim`, so installed apps pick up the new version immediately.

Database changes are applied manually in the Supabase SQL editor **before** pushing code that depends on them.

## Database
SQL migrations and the Excel import scripts live in [`supabase/`](supabase/).
See [CONTEXT.md](CONTEXT.md) for the full schema, screen-by-screen behaviour, and design decisions.
