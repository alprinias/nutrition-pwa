-- ============================================================
-- Migration 010 — RECOVERED SNAPSHOT (already applied, do not re-run)
-- ============================================================
-- Migrations 004b, 007, 008, 009 and the accent-insensitive search
-- functions were run in the Supabase SQL editor but never committed.
-- This file records the functions and RLS policies as they existed in the
-- live database on 2026-10-28, exported via pg_get_functiondef / pg_policies.
--
-- NOT recovered yet: the column/table DDL from those migrations
-- (app_config, moderation_requests, owner_user_id / is_public,
-- show_public_foods, prot_min_g).
-- ============================================================


-- ── Extensions ──────────────────────────────────────────────
-- unaccent is installed in the public schema
create extension if not exists unaccent schema public;


-- ── Search functions (accent-insensitive) ───────────────────
create or replace function public.normalize_text(t text)
returns text language sql immutable strict as $$
  select lower(public.unaccent(t))
$$;

create or replace function public.search_ingredients(q text)
returns setof public.ingredients language sql stable as $$
  select * from public.ingredients
  where public.normalize_text(name) like '%' || public.normalize_text(q) || '%'
  order by name
  limit 50;
$$;

create or replace function public.search_recipes(q text)
returns setof public.recipes language sql stable as $$
  select * from public.recipes
  where public.normalize_text(name) like '%' || public.normalize_text(q) || '%'
  order by name
  limit 30;
$$;


-- ── RLS policies (state as of 2026-10-28) ───────────────────
-- From migration_001 (still present, see migration_011):
--   ingredients_read_all, recipes_read_all, recipe_items_read_all  — select using (true)
--   targets_own, meal_log_own                                       — all using (auth.uid() = user_id)
-- From migration_006:
--   measurements_own                                                — all using (auth.uid() = user_id)

-- From migration_007 / 008:
create policy "app_config_read_all" on public.app_config
  for select using (true);

create policy "ingredients_select" on public.ingredients
  for select using (is_public = true or owner_user_id = auth.uid());
create policy "ingredients_insert" on public.ingredients
  for insert with check (auth.role() = 'authenticated' and owner_user_id = auth.uid() and is_public = false);
create policy "ingredients_update" on public.ingredients
  for update using (
    (owner_user_id = auth.uid() and is_public = false)
    or auth.uid() = (select value::uuid from public.app_config where key = 'admin_user_id'));
create policy "ingredients_delete" on public.ingredients
  for delete using (
    (owner_user_id = auth.uid() and is_public = false)
    or auth.uid() = (select value::uuid from public.app_config where key = 'admin_user_id'));

create policy "recipes_select" on public.recipes
  for select using (is_public = true or owner_user_id = auth.uid());
create policy "recipes_insert" on public.recipes
  for insert with check (auth.role() = 'authenticated' and owner_user_id = auth.uid() and is_public = false);
create policy "recipes_update" on public.recipes
  for update using (
    (owner_user_id = auth.uid() and is_public = false)
    or auth.uid() = (select value::uuid from public.app_config where key = 'admin_user_id'));
create policy "recipes_delete" on public.recipes
  for delete using (
    (owner_user_id = auth.uid() and is_public = false)
    or auth.uid() = (select value::uuid from public.app_config where key = 'admin_user_id'));

create policy "recipe_items_select" on public.recipe_items
  for select using (exists (
    select 1 from public.recipes r
    where r.id = recipe_items.recipe_id and (r.is_public = true or r.owner_user_id = auth.uid())));
create policy "recipe_items_insert" on public.recipe_items
  for insert with check (exists (
    select 1 from public.recipes r
    where r.id = recipe_items.recipe_id
      and (r.owner_user_id = auth.uid()
           or auth.uid() = (select value::uuid from public.app_config where key = 'admin_user_id'))));
create policy "recipe_items_update" on public.recipe_items
  for update using (exists (
    select 1 from public.recipes r
    where r.id = recipe_items.recipe_id
      and (r.owner_user_id = auth.uid()
           or auth.uid() = (select value::uuid from public.app_config where key = 'admin_user_id'))));
create policy "recipe_items_delete" on public.recipe_items
  for delete using (exists (
    select 1 from public.recipes r
    where r.id = recipe_items.recipe_id
      and (r.owner_user_id = auth.uid()
           or auth.uid() = (select value::uuid from public.app_config where key = 'admin_user_id'))));

create policy "mod_requests_select" on public.moderation_requests
  for select using (
    user_id = auth.uid()
    or auth.uid() = (select value::uuid from public.app_config where key = 'admin_user_id'));
create policy "mod_requests_insert" on public.moderation_requests
  for insert with check (user_id = auth.uid());
create policy "mod_requests_update" on public.moderation_requests
  for update using (auth.uid() = (select value::uuid from public.app_config where key = 'admin_user_id'));
