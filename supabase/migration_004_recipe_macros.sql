-- ============================================================
-- migration_004_recipe_macros.sql
-- Adds pre-computed per-serving macro columns to recipes
-- and populates them from recipe_items + ingredients
-- ============================================================

-- 1. Add columns
alter table public.recipes
  add column if not exists calories_per_serving  numeric default 0,
  add column if not exists protein_per_serving   numeric default 0,
  add column if not exists carbs_per_serving     numeric default 0,
  add column if not exists fat_per_serving       numeric default 0;

-- 2. Populate from recipe_items × ingredients
update public.recipes r
set
  calories_per_serving  = totals.cal  / greatest(r.servings, 1),
  protein_per_serving   = totals.prot / greatest(r.servings, 1),
  carbs_per_serving     = totals.carb / greatest(r.servings, 1),
  fat_per_serving       = totals.fat  / greatest(r.servings, 1)
from (
  select
    ri.recipe_id,
    sum(i.calories  * ri.quantity / greatest(i.ref_quantity, 1)) as cal,
    sum(i.protein_g * ri.quantity / greatest(i.ref_quantity, 1)) as prot,
    sum(i.carbs_g   * ri.quantity / greatest(i.ref_quantity, 1)) as carb,
    sum(i.fat_g     * ri.quantity / greatest(i.ref_quantity, 1)) as fat
  from public.recipe_items ri
  join public.ingredients i on i.id = ri.ingredient_id
  group by ri.recipe_id
) totals
where totals.recipe_id = r.id;
