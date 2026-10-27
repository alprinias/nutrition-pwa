-- ============================================================
-- Migration 012 — Align column defaults with app behaviour
-- Run in Supabase SQL editor
-- ============================================================
-- 1. target_kcal default was still 2000 from migration_001; the app's
--    default is 1850. handle_new_user relies on this default, so new users
--    were getting 2000. Existing rows are not changed.
-- 2. New foods are private by default (migration_008 left the default at
--    true; the app always sends false and RLS rejects public inserts).
-- ============================================================

alter table public.user_targets alter column target_kcal set default 1850;

alter table public.ingredients alter column is_public set default false;
alter table public.recipes     alter column is_public set default false;
