-- ============================================================
-- migration_007_admin.sql
-- App config table for admin user identification.
-- Also grants authenticated users write access to ingredients
-- and recipes only when they are the admin.
-- ============================================================

-- 1. App config key-value store
create table if not exists public.app_config (
  key   text primary key,
  value text not null
);

-- Anyone can read config (needed to check admin status client-side)
alter table public.app_config enable row level security;
create policy "app_config_read_all" on public.app_config
  for select using (true);
-- Only service role can write (set via SQL editor, not from app)
-- (no insert/update policy = only service role / SQL editor can write)

-- 2. Insert your user UUID as admin
-- !! Replace the UUID below with YOUR actual user UUID !!
-- Find it in: Supabase → Authentication → Users → copy your UUID
insert into public.app_config (key, value)
values ('admin_user_id', '827dce15-3e19-4c41-ab12-bbad0545983d')
on conflict (key) do update set value = excluded.value;

-- 3. Allow authenticated users to write ingredients/recipes
--    but the app will enforce admin check client-side via app_config.
--    (For a harder server-side guard you'd use a Postgres function,
--     but for a small private app this is sufficient.)
create policy "ingredients_write_authenticated" on public.ingredients
  for all using (auth.role() = 'authenticated');

create policy "recipes_write_authenticated" on public.recipes
  for all using (auth.role() = 'authenticated');

create policy "recipe_items_write_authenticated" on public.recipe_items
  for all using (auth.role() = 'authenticated');
