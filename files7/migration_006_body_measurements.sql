-- ============================================================
-- migration_006_body_measurements.sql
-- Daily body measurements: weight, fat %, water %
-- ============================================================

create table if not exists public.body_measurements (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  measured_at date not null,
  weight_kg  numeric,
  fat_pct    numeric,
  water_pct  numeric,
  note       text,
  unique (user_id, measured_at)
);

alter table public.body_measurements enable row level security;
create policy "measurements_own" on public.body_measurements
  for all using (auth.uid() = user_id);

create index if not exists body_measurements_user_date
  on public.body_measurements (user_id, measured_at);
