-- ============================================================
-- Migration 011 — Fix food visibility and search
-- Run in Supabase SQL editor
-- ============================================================
-- 1. The migration_001 "read_all" policies were never dropped when
--    migration_008 added visibility rules. Permissive policies are OR'ed,
--    so private ingredients/recipes were readable by every user and by
--    unauthenticated requests using the public anon key.
-- 2. The admin read access those policies were silently providing is
--    replaced with explicit admin policies (moderation queue, Foods admin).
-- 3. Owners could still edit the items of a recipe after it became public.
-- 4. Search functions applied LIMIT before the client's owner/category
--    filters, so own items could be cut off. The limit moves to the client.
-- 5. handle_new_user is SECURITY DEFINER; pin its search_path.
-- ============================================================

begin;

-- ── 1. Drop the open read policies ──────────────────────────
drop policy if exists "ingredients_read_all"  on public.ingredients;
drop policy if exists "recipes_read_all"      on public.recipes;
drop policy if exists "recipe_items_read_all" on public.recipe_items;


-- ── 2. Admin can read everything ────────────────────────────
create policy "ingredients_select_admin" on public.ingredients
  for select using (auth.uid() = (select value::uuid from public.app_config where key = 'admin_user_id'));

create policy "recipes_select_admin" on public.recipes
  for select using (auth.uid() = (select value::uuid from public.app_config where key = 'admin_user_id'));

create policy "recipe_items_select_admin" on public.recipe_items
  for select using (auth.uid() = (select value::uuid from public.app_config where key = 'admin_user_id'));


-- ── 3. Recipe items of a public recipe are locked for the owner ──
drop policy if exists "recipe_items_insert" on public.recipe_items;
drop policy if exists "recipe_items_update" on public.recipe_items;
drop policy if exists "recipe_items_delete" on public.recipe_items;

create policy "recipe_items_insert" on public.recipe_items
  for insert with check (exists (
    select 1 from public.recipes r
    where r.id = recipe_items.recipe_id
      and ((r.owner_user_id = auth.uid() and r.is_public = false)
           or auth.uid() = (select value::uuid from public.app_config where key = 'admin_user_id'))));

create policy "recipe_items_update" on public.recipe_items
  for update using (exists (
    select 1 from public.recipes r
    where r.id = recipe_items.recipe_id
      and ((r.owner_user_id = auth.uid() and r.is_public = false)
           or auth.uid() = (select value::uuid from public.app_config where key = 'admin_user_id'))));

create policy "recipe_items_delete" on public.recipe_items
  for delete using (exists (
    select 1 from public.recipes r
    where r.id = recipe_items.recipe_id
      and ((r.owner_user_id = auth.uid() and r.is_public = false)
           or auth.uid() = (select value::uuid from public.app_config where key = 'admin_user_id'))));


-- ── 4. Search functions without LIMIT (client applies it) ───
create or replace function public.search_ingredients(q text)
returns setof public.ingredients language sql stable as $$
  select * from public.ingredients
  where public.normalize_text(name) like '%' || public.normalize_text(q) || '%'
  order by name;
$$;

create or replace function public.search_recipes(q text)
returns setof public.recipes language sql stable as $$
  select * from public.recipes
  where public.normalize_text(name) like '%' || public.normalize_text(q) || '%'
  order by name;
$$;


-- ── 5. Pin search_path on the SECURITY DEFINER trigger ──────
alter function public.handle_new_user() set search_path = '';

commit;
