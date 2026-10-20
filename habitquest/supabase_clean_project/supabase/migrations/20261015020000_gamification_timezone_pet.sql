-- Clean-install security, timezone, gamification, and pet schema.
-- Built from the reviewed final repair definitions, without the existing-schema
-- preflight because this migration follows the clean core migration.

begin;

create table public.xp_ledger (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  idempotency_key text not null,
  amount integer not null check (amount > 0),
  awarded_on date not null,
  created_at timestamptz not null default pg_catalog.now(),
  constraint xp_ledger_user_idempotency_key
    unique (user_id, idempotency_key)
);

create table public.user_achievements (
  user_id uuid not null references auth.users(id) on delete cascade,
  achievement_key text not null,
  unlocked_at timestamptz not null default pg_catalog.now(),
  constraint user_achievements_pkey primary key (user_id, achievement_key),
  constraint user_achievements_known_key check (
    achievement_key in ('first_completion', 'streak_7', 'completion_25')
  )
);

alter table public.xp_ledger enable row level security;
alter table public.user_achievements enable row level security;
revoke all on table public.xp_ledger, public.user_achievements
  from anon, authenticated, public;
grant select on table public.xp_ledger, public.user_achievements
  to authenticated;

create policy "Users can view their own XP ledger"
  on public.xp_ledger for select to authenticated
  using (user_id = (select auth.uid()));
create policy "Users can view their own achievements"
  on public.user_achievements for select to authenticated
  using (user_id = (select auth.uid()));

create table public.completion_write_verifications (
  user_id uuid not null references auth.users(id) on delete cascade,
  habit_id uuid not null,
  completed_on date not null,
  verified_at timestamptz not null default pg_catalog.now(),
  time_zone text,
  constraint completion_write_verifications_pkey
    primary key (habit_id, completed_on),
  constraint completion_write_verifications_completion_fkey
    foreign key (habit_id, completed_on)
    references public.habit_completions(habit_id, completed_on)
    on delete cascade
);

alter table public.completion_write_verifications enable row level security;
revoke all on table public.completion_write_verifications
  from anon, authenticated, public;

create table public.user_completion_time_zones (
  user_id uuid primary key references auth.users(id) on delete cascade,
  time_zone text not null,
  updated_at timestamptz not null
    default pg_catalog.transaction_timestamp()
);

alter table public.user_completion_time_zones enable row level security;
revoke all on table public.user_completion_time_zones
  from anon, authenticated, public;

create table public.pet_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  pet_name text not null default 'Mochi'
    check (pg_catalog.char_length(pg_catalog.btrim(pet_name)) between 1 and 24),
  equipped_item_key text
    check (equipped_item_key is null or equipped_item_key in (
      'leaf_crown', 'star_glasses', 'aurora_charm'
    )),
  updated_at timestamptz not null default pg_catalog.now()
);

alter table public.pet_preferences enable row level security;
revoke all on table public.pet_preferences from anon, authenticated, public;
grant select on table public.pet_preferences to authenticated;
create policy "Users can view their own pet preferences"
  on public.pet_preferences for select to authenticated
  using (user_id = (select auth.uid()));

create or replace function public.get_completion_time_zone()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_settings jsonb;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  select pg_catalog.jsonb_build_object(
    'time_zone', s.time_zone,
    'updated_at', s.updated_at,
    'next_change_at', s.updated_at + interval '30 days'
  ) into v_settings
  from public.user_completion_time_zones s
  where s.user_id = v_user_id;
  return v_settings;
  end;
$function$;

create or replace function public.set_completion_time_zone(p_time_zone text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_time_zone text := pg_catalog.btrim(p_time_zone);
  v_existing_zone text;
  v_updated_at timestamptz;
  v_inserted integer;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if v_time_zone is null or pg_catalog.char_length(v_time_zone) > 100
     or (v_time_zone <> 'UTC' and pg_catalog.strpos(v_time_zone, '/') = 0)
     or not exists (
       select 1 from pg_catalog.pg_timezone_names z
       where z.name = v_time_zone
         and z.name not like 'posix/%'
         and z.name not like 'right/%'
     ) then
    raise exception 'A valid IANA timezone is required'
      using errcode = '22023';
  end if;

  insert into public.user_completion_time_zones(user_id, time_zone)
  values (v_user_id, v_time_zone)
  on conflict (user_id) do nothing;
  get diagnostics v_inserted = row_count;

  if v_inserted = 0 then
    select s.time_zone, s.updated_at into v_existing_zone, v_updated_at
    from public.user_completion_time_zones s
    where s.user_id = v_user_id
    for update;
    if v_existing_zone <> v_time_zone then
      if v_updated_at >
         pg_catalog.transaction_timestamp() - interval '30 days' then
        raise exception 'Timezone changes are limited to once every 30 days'
          using errcode = '22023';
      end if;
      update public.user_completion_time_zones
      set time_zone = v_time_zone,
          updated_at = pg_catalog.transaction_timestamp()
      where user_id = v_user_id;
      v_updated_at := pg_catalog.transaction_timestamp();
    end if;
  else
    v_updated_at := pg_catalog.transaction_timestamp();
  end if;

  return pg_catalog.jsonb_build_object(
    'time_zone', v_time_zone,
    'updated_at', v_updated_at,
    'next_change_at', v_updated_at + interval '30 days'
  );
  end;
$function$;

create or replace function public.get_verified_completion_count()
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_count integer;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  select pg_catalog.count(*)::integer into v_count
  from public.completion_write_verifications v
  join public.habits h on h.id = v.habit_id
  where v.user_id = v_user_id and h.user_id = v_user_id;
  return coalesce(v_count, 0);
  end;
$function$;

create or replace function public.get_verified_completion_keys()
returns table (habit_id uuid, completed_on date)
language sql
stable
security definer
set search_path = ''
as $function$
  select v.habit_id, v.completed_on
  from public.completion_write_verifications v
  join public.habits h on h.id = v.habit_id
  where v.user_id = (select auth.uid())
    and h.user_id = (select auth.uid())
$function$;

create or replace function public.record_habit_completion(p_habit_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_time_zone text;
  v_server_date date;
  v_inserted integer;
  v_verified boolean := false;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if p_habit_id is null then
    raise exception 'Habit is required' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.habits h
    where h.id = p_habit_id and h.user_id = v_user_id
  ) then
    raise exception 'Habit not found for this account' using errcode = '42501';
  end if;

  select s.time_zone into v_time_zone
  from public.user_completion_time_zones s
  where s.user_id = v_user_id;
  if v_time_zone is null
     or (v_time_zone <> 'UTC' and pg_catalog.strpos(v_time_zone, '/') = 0)
     or not exists (
       select 1 from pg_catalog.pg_timezone_names z
       where z.name = v_time_zone
         and z.name not like 'posix/%'
         and z.name not like 'right/%'
     ) then
    raise exception 'Completion timezone is missing or invalid'
      using errcode = 'P0001';
  end if;

  v_server_date := pg_catalog.timezone(
    v_time_zone, pg_catalog.transaction_timestamp()
  )::date;

  insert into public.habit_completions(habit_id, completed_on)
  values (p_habit_id, v_server_date)
  on conflict (habit_id, completed_on) do nothing;
  get diagnostics v_inserted = row_count;

  if v_inserted > 0 then
    insert into public.completion_write_verifications
      (user_id, habit_id, completed_on, time_zone)
    values (v_user_id, p_habit_id, v_server_date, v_time_zone);
    v_verified := true;
  else
    select exists (
      select 1 from public.completion_write_verifications v
      where v.user_id = v_user_id
        and v.habit_id = p_habit_id
        and v.completed_on = v_server_date
    ) into v_verified;
  end if;

  return pg_catalog.jsonb_build_object(
    'completed_on', v_server_date,
    'is_verified', v_verified,
    'inserted', v_inserted > 0
  );
  end;
$function$;

create or replace function public.claim_completion_rewards(
  p_habit_id uuid,
  p_completed_on date
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_completion_time_zone text;
  v_daily_count integer;
  v_lifetime_count integer;
  v_seven_day_streak boolean;
  v_new_xp integer := 0;
  v_total_xp bigint;
  v_unlocked text[] := array[]::text[];
  v_added integer;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  select v.time_zone into v_completion_time_zone
  from public.completion_write_verifications v
  where v.user_id = v_user_id
    and v.habit_id = p_habit_id
    and v.completed_on = p_completed_on;
  if not found then
    raise exception 'Verified completion record not found' using errcode = 'P0002';
  end if;
  if p_completed_on > pg_catalog.timezone(
       coalesce(v_completion_time_zone, 'UTC'),
       pg_catalog.transaction_timestamp()
     )::date then
    raise exception 'Future-dated completions cannot receive rewards'
      using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.habit_completions c
    join public.habits h on h.id = c.habit_id
    where c.habit_id = p_habit_id
      and c.completed_on = p_completed_on
      and h.user_id = v_user_id
  ) then
    raise exception 'Completion record not found' using errcode = 'P0002';
  end if;

  select pg_catalog.count(*)::integer into v_daily_count
  from public.completion_write_verifications v
  join public.habits h on h.id = v.habit_id
  where v.user_id = v_user_id and h.user_id = v_user_id
    and v.completed_on = p_completed_on;
  select pg_catalog.count(*)::integer into v_lifetime_count
  from public.completion_write_verifications v
  join public.habits h on h.id = v.habit_id
  where v.user_id = v_user_id and h.user_id = v_user_id;

  select not exists (
    select 1
    from pg_catalog.generate_series(0, 6) as d(offset_days)
    where not exists (
      select 1
      from public.completion_write_verifications v
      where v.user_id = v_user_id
        and v.habit_id = p_habit_id
        and v.completed_on = p_completed_on - d.offset_days
    )
  ) into v_seven_day_streak;

  insert into public.xp_ledger(user_id, idempotency_key, amount, awarded_on)
  values (v_user_id,
    'completion:' || p_habit_id::text || ':' || p_completed_on::text,
    10, p_completed_on)
  on conflict (user_id, idempotency_key) do nothing;
  get diagnostics v_added = row_count;
  v_new_xp := v_new_xp + v_added * 10;

  if v_daily_count >= 1 then
    insert into public.xp_ledger(user_id, idempotency_key, amount, awarded_on)
    values (v_user_id, 'quest:one:' || p_completed_on::text, 5, p_completed_on)
    on conflict (user_id, idempotency_key) do nothing;
    get diagnostics v_added = row_count;
    v_new_xp := v_new_xp + v_added * 5;
  end if;
  if v_daily_count >= 3 then
    insert into public.xp_ledger(user_id, idempotency_key, amount, awarded_on)
    values (v_user_id, 'quest:three:' || p_completed_on::text, 15, p_completed_on)
    on conflict (user_id, idempotency_key) do nothing;
    get diagnostics v_added = row_count;
    v_new_xp := v_new_xp + v_added * 15;
  end if;

  if v_lifetime_count >= 1 then
    insert into public.user_achievements(user_id, achievement_key)
    values (v_user_id, 'first_completion') on conflict do nothing;
    get diagnostics v_added = row_count;
    if v_added > 0 then
      v_unlocked := pg_catalog.array_append(v_unlocked, 'first_completion');
      insert into public.xp_ledger(user_id, idempotency_key, amount, awarded_on)
      values (v_user_id, 'achievement:first_completion', 20, p_completed_on)
      on conflict (user_id, idempotency_key) do nothing;
      get diagnostics v_added = row_count;
      v_new_xp := v_new_xp + v_added * 20;
    end if;
  end if;
  if coalesce(v_seven_day_streak, false) then
    insert into public.user_achievements(user_id, achievement_key)
    values (v_user_id, 'streak_7') on conflict do nothing;
    get diagnostics v_added = row_count;
    if v_added > 0 then
      v_unlocked := pg_catalog.array_append(v_unlocked, 'streak_7');
      insert into public.xp_ledger(user_id, idempotency_key, amount, awarded_on)
      values (v_user_id, 'achievement:streak_7', 50, p_completed_on)
      on conflict (user_id, idempotency_key) do nothing;
      get diagnostics v_added = row_count;
      v_new_xp := v_new_xp + v_added * 50;
    end if;
  end if;
  if v_lifetime_count >= 25 then
    insert into public.user_achievements(user_id, achievement_key)
    values (v_user_id, 'completion_25') on conflict do nothing;
    get diagnostics v_added = row_count;
    if v_added > 0 then
      v_unlocked := pg_catalog.array_append(v_unlocked, 'completion_25');
      insert into public.xp_ledger(user_id, idempotency_key, amount, awarded_on)
      values (v_user_id, 'achievement:completion_25', 75, p_completed_on)
      on conflict (user_id, idempotency_key) do nothing;
      get diagnostics v_added = row_count;
      v_new_xp := v_new_xp + v_added * 75;
    end if;
  end if;

  select coalesce(pg_catalog.sum(amount), 0)::bigint into v_total_xp
  from public.xp_ledger where user_id = v_user_id;
  return pg_catalog.jsonb_build_object(
    'earned_xp', v_new_xp,
    'total_xp', v_total_xp,
    'daily_completed', v_daily_count,
    'unlocked', pg_catalog.to_jsonb(v_unlocked)
  );
  end;
$function$;

create or replace function public.save_pet_preferences(
  p_pet_name text,
  p_equipped_item_key text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := auth.uid();
  v_pet_name text := pg_catalog.btrim(p_pet_name);
  v_completion_count integer;
  v_required_completions integer;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if v_pet_name is null
     or pg_catalog.char_length(v_pet_name) not between 1 and 24
     or v_pet_name ~ '[[:cntrl:]]' then
    raise exception 'Pet name must be 1 to 24 printable characters'
      using errcode = '22023';
  end if;

  if p_equipped_item_key is null then
    v_required_completions := 0;
  else
    v_required_completions := case p_equipped_item_key
      when 'leaf_crown' then 3
      when 'star_glasses' then 10
      when 'aurora_charm' then 25
      else null
    end;
    if v_required_completions is null then
      raise exception 'Unknown pet cosmetic' using errcode = '22023';
    end if;
  end if;

  select pg_catalog.count(*)::integer into v_completion_count
  from public.completion_write_verifications v
  join public.habits h on h.id = v.habit_id
  where v.user_id = v_user_id and h.user_id = v_user_id;
  if v_completion_count < v_required_completions then
    raise exception 'Pet cosmetic has not been unlocked'
      using errcode = '42501';
  end if;

  insert into public.pet_preferences(user_id, pet_name, equipped_item_key)
  values (v_user_id, v_pet_name, p_equipped_item_key)
  on conflict (user_id) do update
  set pet_name = excluded.pet_name,
      equipped_item_key = excluded.equipped_item_key,
      updated_at = pg_catalog.now();

  return pg_catalog.jsonb_build_object(
    'pet_name', v_pet_name,
    'equipped_item_key', p_equipped_item_key
  );
  end;
$function$;

-- Effective EXECUTE is only for authenticated. No RPC is callable by anon or
-- PUBLIC. Also clear any explicit authenticated grant before adding it back.
revoke all on function public.get_completion_time_zone()
  from public, anon, authenticated;
revoke all on function public.set_completion_time_zone(text)
  from public, anon, authenticated;
revoke all on function public.get_verified_completion_count()
  from public, anon, authenticated;
revoke all on function public.get_verified_completion_keys()
  from public, anon, authenticated;
revoke all on function public.record_habit_completion(uuid)
  from public, anon, authenticated;
revoke all on function public.claim_completion_rewards(uuid, date)
  from public, anon, authenticated;
revoke all on function public.save_pet_preferences(text, text)
  from public, anon, authenticated;

grant execute on function public.get_completion_time_zone()
  to authenticated;
grant execute on function public.set_completion_time_zone(text)
  to authenticated;
grant execute on function public.get_verified_completion_count()
  to authenticated;
grant execute on function public.get_verified_completion_keys()
  to authenticated;
grant execute on function public.record_habit_completion(uuid)
  to authenticated;
grant execute on function public.claim_completion_rewards(uuid, date)
  to authenticated;
grant execute on function public.save_pet_preferences(text, text)
  to authenticated;

revoke all on table public.habit_completions from anon, authenticated, public;
grant select on table public.habit_completions to authenticated;
drop policy if exists "Users can create completions for their own habits"
  on public.habit_completions;

-- POSTFLIGHT: fail before commit on unexpected function security or ACLs.
do $postflight$
declare
  v_count integer;
  v_bad integer;
begin
  select count(*) into v_count
  from (
    values
      ('public.get_completion_time_zone()'::regprocedure),
      ('public.set_completion_time_zone(text)'::regprocedure),
      ('public.get_verified_completion_count()'::regprocedure),
      ('public.get_verified_completion_keys()'::regprocedure),
      ('public.record_habit_completion(uuid)'::regprocedure),
      ('public.claim_completion_rewards(uuid,date)'::regprocedure),
      ('public.save_pet_preferences(text,text)'::regprocedure)
  ) expected(oid)
  join pg_catalog.pg_proc p on p.oid = expected.oid
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.prosecdef
    and p.proconfig @> array['search_path=""']
    and pg_catalog.pg_get_userbyid(p.proowner) = current_user
    and current_user not in ('anon', 'authenticated');

  if v_count <> 7 then
    raise exception 'Expected seven SECURITY DEFINER functions owned by executor';
  end if;

  if to_regprocedure('public.record_habit_completion(uuid,date)') is not null then
    raise exception 'Obsolete client-date completion RPC exists';
  end if;

  if (select p.prorettype <> 'jsonb'::regtype or p.proretset
      from pg_catalog.pg_proc p
      where p.oid = to_regprocedure('public.get_completion_time_zone()'))
     or (select p.prorettype <> 'jsonb'::regtype or p.proretset
      from pg_catalog.pg_proc p
      where p.oid = to_regprocedure('public.set_completion_time_zone(text)'))
     or (select p.prorettype <> 'jsonb'::regtype or p.proretset
      from pg_catalog.pg_proc p
      where p.oid = to_regprocedure('public.record_habit_completion(uuid)'))
     or (select p.prorettype <> 'jsonb'::regtype or p.proretset
      from pg_catalog.pg_proc p
      where p.oid = to_regprocedure('public.claim_completion_rewards(uuid,date)'))
     or (select p.prorettype <> 'integer'::regtype or p.proretset
      from pg_catalog.pg_proc p
      where p.oid = to_regprocedure('public.get_verified_completion_count()'))
      or (select p.prokind <> 'f'
                or p.prorettype <> 'record'::regtype
                or not p.proretset
                or p.pronargs <> 0
                or p.proargnames is distinct from
                     array['habit_id', 'completed_on']::text[]
                or p.proallargtypes is distinct from
                     array['uuid'::regtype::oid, 'date'::regtype::oid]
                or p.proargmodes is distinct from
                     array['t'::"char", 't'::"char"]
      from pg_catalog.pg_proc p
      where p.oid = to_regprocedure('public.get_verified_completion_keys()'))
     or (select p.prorettype <> 'jsonb'::regtype or p.proretset
      from pg_catalog.pg_proc p
      where p.oid = to_regprocedure('public.save_pet_preferences(text,text)')) then
    raise exception 'RPC return shape differs from the Dart contract';
  end if;

  -- PostgREST dispatches named arguments by their PostgreSQL input names,
  -- so matching only the type signatures is not sufficient for RPC clients.
  if (select p.proargnames is distinct from array['p_time_zone']::text[]
      from pg_catalog.pg_proc p
      where p.oid = to_regprocedure('public.set_completion_time_zone(text)'))
     or (select p.proargnames is distinct from array['p_habit_id']::text[]
      from pg_catalog.pg_proc p
      where p.oid = to_regprocedure('public.record_habit_completion(uuid)'))
     or (select p.proargnames is distinct from
           array['p_habit_id', 'p_completed_on']::text[]
      from pg_catalog.pg_proc p
      where p.oid = to_regprocedure('public.claim_completion_rewards(uuid,date)'))
     or (select p.proargnames is distinct from
           array['p_pet_name', 'p_equipped_item_key']::text[]
      from pg_catalog.pg_proc p
      where p.oid = to_regprocedure('public.save_pet_preferences(text,text)'))
     or (select p.proargnames is distinct from
           array['habit_id', 'completed_on']::text[]
      from pg_catalog.pg_proc p
      where p.oid = to_regprocedure('public.get_verified_completion_keys()')) then
    raise exception 'RPC argument names differ from the Dart/PostgREST contract';
  end if;

  if not has_function_privilege('authenticated',
       'public.get_completion_time_zone()', 'EXECUTE')
     or not has_function_privilege('authenticated',
       'public.set_completion_time_zone(text)', 'EXECUTE')
     or not has_function_privilege('authenticated',
       'public.get_verified_completion_count()', 'EXECUTE')
     or not has_function_privilege('authenticated',
       'public.get_verified_completion_keys()', 'EXECUTE')
     or not has_function_privilege('authenticated',
       'public.record_habit_completion(uuid)', 'EXECUTE')
     or not has_function_privilege('authenticated',
       'public.claim_completion_rewards(uuid,date)', 'EXECUTE')
     or not has_function_privilege('authenticated',
       'public.save_pet_preferences(text,text)', 'EXECUTE') then
    raise exception 'Authenticated EXECUTE grants are incomplete';
  end if;

  if has_function_privilege('anon',
       'public.get_completion_time_zone()', 'EXECUTE')
     or has_function_privilege('anon',
       'public.set_completion_time_zone(text)', 'EXECUTE')
     or has_function_privilege('anon',
       'public.get_verified_completion_count()', 'EXECUTE')
     or has_function_privilege('anon',
       'public.get_verified_completion_keys()', 'EXECUTE')
     or has_function_privilege('anon',
       'public.record_habit_completion(uuid)', 'EXECUTE')
     or has_function_privilege('anon',
       'public.claim_completion_rewards(uuid,date)', 'EXECUTE')
     or has_function_privilege('anon',
       'public.save_pet_preferences(text,text)', 'EXECUTE') then
    raise exception 'anon has an unexpected EXECUTE privilege';
  end if;

  if exists (
    select 1
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    cross join lateral pg_catalog.aclexplode(
      coalesce(p.proacl, pg_catalog.acldefault('f', p.proowner))
    ) a
    where n.nspname = 'public'
      and p.proname in (
        'get_completion_time_zone', 'set_completion_time_zone',
        'get_verified_completion_count', 'get_verified_completion_keys',
        'record_habit_completion', 'claim_completion_rewards',
        'save_pet_preferences'
      )
      and a.grantee = 0
      and a.privilege_type = 'EXECUTE'
  ) then
    raise exception 'PUBLIC has an unexpected EXECUTE grant';
  end if;

  if exists (
    select 1
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    cross join lateral pg_catalog.aclexplode(
      coalesce(p.proacl, pg_catalog.acldefault('f', p.proowner))
    ) a
    where n.nspname = 'public'
      and p.proname in (
        'get_completion_time_zone', 'set_completion_time_zone',
        'get_verified_completion_count', 'get_verified_completion_keys',
        'record_habit_completion', 'claim_completion_rewards',
        'save_pet_preferences'
      )
      and a.privilege_type = 'EXECUTE'
      and a.grantee not in (
        p.proowner,
        (select r.oid from pg_catalog.pg_roles r
         where r.rolname = 'authenticated')
      )
  ) then
    raise exception 'An unexpected role has an RPC EXECUTE grant';
  end if;

  if has_table_privilege('authenticated',
       'public.habit_completions', 'INSERT')
     or not has_table_privilege('authenticated',
       'public.habit_completions', 'SELECT')
     or has_table_privilege('anon',
       'public.habit_completions', 'INSERT')
     or not has_column_privilege('authenticated',
       'public.habits', 'name', 'UPDATE')
     or not has_column_privilege('authenticated',
       'public.habits', 'category', 'UPDATE')
     or not has_column_privilege('authenticated',
       'public.habits', 'frequency', 'UPDATE')
     or not has_column_privilege('authenticated',
       'public.habits', 'streak', 'UPDATE')
     or not has_column_privilege('authenticated',
       'public.habits', 'last_completed_date', 'UPDATE') then
    raise exception 'Effective table privileges differ from secure target';
  end if;

  if not (
    select c.relrowsecurity and not c.relforcerowsecurity
    from pg_catalog.pg_class c
    where c.oid = 'public.habits'::regclass
  ) or not (
    select c.relrowsecurity and not c.relforcerowsecurity
    from pg_catalog.pg_class c
    where c.oid = 'public.habit_completions'::regclass
  ) then
    raise exception 'Existing table RLS state changed unexpectedly';
  end if;

  select count(*) into v_bad
  from pg_catalog.pg_class c
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public'
    and c.relname in (
      'xp_ledger', 'user_achievements', 'completion_write_verifications',
      'user_completion_time_zones', 'pet_preferences'
    )
    and (not c.relrowsecurity or c.relforcerowsecurity);
  if v_bad <> 0 then
    raise exception 'A private table has unexpected RLS enabled/FORCED state';
  end if;

  if not has_column_privilege('authenticated',
       'public.habits', 'name', 'UPDATE')
     or not has_column_privilege('authenticated',
       'public.habits', 'category', 'UPDATE')
     or not has_column_privilege('authenticated',
       'public.habits', 'frequency', 'UPDATE')
     or not has_column_privilege('authenticated',
       'public.habits', 'streak', 'UPDATE')
     or not has_column_privilege('authenticated',
       'public.habits', 'last_completed_date', 'UPDATE') then
    raise exception 'Authenticated habits column UPDATE permissions changed';
  end if;

  if has_table_privilege('authenticated',
       'public.completion_write_verifications', 'SELECT')
     or has_table_privilege('authenticated',
       'public.user_completion_time_zones', 'SELECT')
     or has_table_privilege('authenticated', 'public.xp_ledger', 'INSERT')
     or has_table_privilege('authenticated',
       'public.user_achievements', 'INSERT')
     or not has_table_privilege('authenticated', 'public.xp_ledger', 'SELECT')
     or not has_table_privilege(
       'authenticated', 'public.user_achievements', 'SELECT')
     or not has_table_privilege(
       'authenticated', 'public.pet_preferences', 'SELECT') then
    raise exception 'Supporting-table privileges differ from least privilege';
  end if;

  if not exists (
    select 1 from pg_catalog.pg_policies p
    where p.schemaname = 'public' and p.tablename = 'xp_ledger'
      and p.policyname = 'Users can view their own XP ledger'
      and p.cmd = 'SELECT' and p.roles = array['authenticated']::name[]
      and lower(coalesce(p.qual, '')) like '%user_id%'
      and lower(coalesce(p.qual, '')) like '%auth.uid%'
  ) or not exists (
    select 1 from pg_catalog.pg_policies p
    where p.schemaname = 'public' and p.tablename = 'user_achievements'
      and p.policyname = 'Users can view their own achievements'
      and p.cmd = 'SELECT' and p.roles = array['authenticated']::name[]
      and lower(coalesce(p.qual, '')) like '%user_id%'
      and lower(coalesce(p.qual, '')) like '%auth.uid%'
  ) or not exists (
    select 1 from pg_catalog.pg_policies p
    where p.schemaname = 'public' and p.tablename = 'pet_preferences'
      and p.policyname = 'Users can view their own pet preferences'
      and p.cmd = 'SELECT' and p.roles = array['authenticated']::name[]
      and lower(coalesce(p.qual, '')) like '%user_id%'
      and lower(coalesce(p.qual, '')) like '%auth.uid%'
  ) then
    raise exception 'Expected owner-scoped supporting-table policies are absent';
  end if;

  if exists (
    select 1 from pg_catalog.pg_policies p
    where p.schemaname = 'public'
      and p.tablename in ('completion_write_verifications',
                          'user_completion_time_zones')
  ) then
    raise exception 'Private verification/timezone tables have an unexpected policy';
  end if;
  end;
$postflight$;

commit;

