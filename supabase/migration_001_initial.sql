-- ============================================================
-- Nutrition PWA — Supabase database migration
-- Run this in: Supabase dashboard → SQL Editor → New query
-- ============================================================


-- 1. INGREDIENTS (shared reference data, read-only for all users)
create table if not exists public.ingredients (
  id          serial primary key,
  name        text not null,
  category    text,
  unit        text not null default 'gr',   -- gr | slc | pc
  ref_quantity numeric not null default 100,
  calories    numeric not null default 0,
  protein_g   numeric not null default 0,
  carbs_g     numeric not null default 0,
  fat_g       numeric not null default 0,
  sodium_mg   numeric,
  potassium_mg numeric,
  created_at  timestamptz default now()
);

-- Anyone can read ingredients; only service role can write (admin imports)
alter table public.ingredients enable row level security;
create policy "ingredients_read_all" on public.ingredients
  for select using (true);


-- 2. RECIPES (shared, read-only for all users)
create table if not exists public.recipes (
  id             serial primary key,
  name           text not null,
  total_weight_g numeric,
  servings       integer default 1,
  unit           text default 'gr',   -- gr | pc
  created_at     timestamptz default now()
);

alter table public.recipes enable row level security;
create policy "recipes_read_all" on public.recipes
  for select using (true);


-- 3. RECIPE ITEMS (ingredients that make up a recipe)
create table if not exists public.recipe_items (
  id            serial primary key,
  recipe_id     integer not null references public.recipes(id) on delete cascade,
  ingredient_id integer not null references public.ingredients(id),
  quantity      numeric not null,
  unit          text not null
);

alter table public.recipe_items enable row level security;
create policy "recipe_items_read_all" on public.recipe_items
  for select using (true);


-- 4. USER TARGETS (per-user macro goals)
create table if not exists public.user_targets (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  prot_min_pct    numeric default 25,
  prot_max_pct    numeric default 35,
  carb_min_pct    numeric default 40,
  carb_max_pct    numeric default 50,
  fat_min_pct     numeric default 20,
  fat_max_pct     numeric default 35,
  carb_min_g      numeric default 135,
  target_kcal     numeric default 2000,
  updated_at      timestamptz default now(),
  unique (user_id)
);

alter table public.user_targets enable row level security;
create policy "targets_own" on public.user_targets
  for all using (auth.uid() = user_id);


-- 5. MEAL LOG (daily entries, fully per-user)
create table if not exists public.meal_log (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  logged_at     timestamptz not null default now(),

  -- Either a full recipe or a single ingredient (one must be set)
  recipe_id     integer references public.recipes(id),
  ingredient_id integer references public.ingredients(id),

  quantity      numeric not null,
  unit          text not null,
  note          text,

  -- Snapshot of macros at log time (so edits to ingredient don't break history)
  calories      numeric not null default 0,
  protein_g     numeric not null default 0,
  carbs_g       numeric not null default 0,
  fat_g         numeric not null default 0,

  constraint meal_has_food check (
    (recipe_id is not null) <> (ingredient_id is not null)
    or (recipe_id is null and ingredient_id is null)  -- allow free-text note-only entries
  )
);

alter table public.meal_log enable row level security;
create policy "meal_log_own" on public.meal_log
  for all using (auth.uid() = user_id);

-- Index for fast daily queries
create index if not exists meal_log_user_date
  on public.meal_log (user_id, logged_at);


-- 6. HELPER FUNCTION — auto-create default targets for new users
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.user_targets (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

-- Trigger: fires when a new user signs up
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
