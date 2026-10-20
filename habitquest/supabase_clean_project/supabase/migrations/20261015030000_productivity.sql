-- Mood journal and habit reminders for the clean HabitQuest setup.

begin;

-- Mood notes are private to one authenticated account. Reminder rows store a
-- local wall-clock preference only; no notification scheduler is installed.

create table public.mood_entries (
  user_id uuid not null references auth.users (id) on delete cascade,
  entry_date date not null,
  mood text not null
    check (mood in ('great', 'good', 'okay', 'low', 'rough')),
  note text not null default ''
    check (pg_catalog.char_length(note) <= 280),
  updated_at timestamptz not null default now(),
  constraint mood_entries_pkey primary key (user_id, entry_date)
);

alter table public.mood_entries enable row level security;
revoke all on table public.mood_entries from anon, authenticated, public;
grant select, insert, update, delete on table public.mood_entries to authenticated;
create policy "Users can manage their own mood entries"
  on public.mood_entries for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create table public.habit_reminders (
  user_id uuid not null references auth.users (id) on delete cascade,
  habit_id uuid not null references public.habits (id) on delete cascade,
  enabled boolean not null default false,
  reminder_time time not null default time '09:00',
  updated_at timestamptz not null default now(),
  constraint habit_reminders_pkey primary key (user_id, habit_id)
);

alter table public.habit_reminders enable row level security;
revoke all on table public.habit_reminders from anon, authenticated, public;
grant select, insert, update, delete on table public.habit_reminders to authenticated;
create policy "Users can manage reminders for their own habits"
  on public.habit_reminders for all to authenticated
  using (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.habits h
      where h.id = habit_id and h.user_id = (select auth.uid())
    )
  )
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.habits h
      where h.id = habit_id and h.user_id = (select auth.uid())
    )
  );

commit;

