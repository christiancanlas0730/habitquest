-- Clean-install core schema for a brand-new HabitQuest Supabase project.
-- This isolated migration directory intentionally excludes the prepared
-- migrations in ../supabase/migrations; it does not touch the existing project.

begin;

revoke create on schema public from public, anon, authenticated;
grant usage on schema public to anon, authenticated;

create table public.habits (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null check (pg_catalog.char_length(pg_catalog.btrim(name)) > 0),
  category text not null default 'Other'
    check (category in ('Study', 'Health', 'Fitness', 'Personal', 'Other')),
  frequency text not null default 'Daily'
    check (frequency in (
      'Daily', 'Weekly', 'Every day', 'Weekdays', 'Weekends',
      'Once a week', 'Twice a week', 'Once a month'
    )),
  streak integer not null default 0 check (streak >= 0),
  last_completed_date date,
  created_at timestamptz not null default pg_catalog.now()
);

create index habits_user_created_at_idx
  on public.habits (user_id, created_at desc);

alter table public.habits enable row level security;
revoke all on table public.habits from public, anon, authenticated;
grant select, insert, delete on table public.habits to authenticated;
grant update (name, category, frequency, streak, last_completed_date)
  on table public.habits to authenticated;

create policy habits_select_own
  on public.habits for select to authenticated
  using (user_id = (select auth.uid()));
create policy habits_insert_own
  on public.habits for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy habits_update_own
  on public.habits for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy habits_delete_own
  on public.habits for delete to authenticated
  using (user_id = (select auth.uid()));

create table public.habit_completions (
  habit_id uuid not null references public.habits (id) on delete cascade,
  completed_on date not null,
  created_at timestamptz not null default pg_catalog.now(),
  constraint habit_completions_pkey primary key (habit_id, completed_on)
);

alter table public.habit_completions enable row level security;
revoke all on table public.habit_completions from public, anon, authenticated;
grant select on table public.habit_completions to authenticated;

create policy habit_completions_select_own
  on public.habit_completions for select to authenticated
  using (
    exists (
      select 1
      from public.habits h
      where h.id = habit_id and h.user_id = (select auth.uid())
    )
  );

commit;
