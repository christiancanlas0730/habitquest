-- HabitQuest read-only production compatibility audit.
-- Before running: verify the Supabase Dashboard URL shows project ref
-- puuzmqabbtbxgcbxwrzb. This script only reads PostgreSQL catalogs.
-- Run each SELECT block separately if the SQL Editor displays one result set
-- at a time. Do not add migration or DDL statements to this script.

-- 1. Expected relations, columns, types, nullability, and defaults.
with expected(table_name, expected_columns) as (
  values
    ('habits', array['id','user_id','name','category','frequency','streak','last_completed_date','created_at']::text[]),
    ('habit_completions', array['habit_id','completed_on','created_at']::text[]),
    ('xp_ledger', array['id','user_id','idempotency_key','amount','awarded_on','created_at']::text[]),
    ('user_achievements', array['user_id','achievement_key','unlocked_at']::text[]),
    ('completion_write_verifications', array['user_id','habit_id','completed_on','verified_at','time_zone']::text[]),
    ('user_completion_time_zones', array['user_id','time_zone','updated_at']::text[]),
    ('pet_preferences', array['user_id','pet_name','equipped_item_key','updated_at']::text[]),
    ('mood_entries', array['user_id','entry_date','mood','note','updated_at']::text[]),
    ('habit_reminders', array['user_id','habit_id','enabled','reminder_time','updated_at']::text[])
)
select e.table_name,
       x.column_name,
       pg_catalog.format_type(a.atttypid, a.atttypmod) as data_type,
       a.attnotnull as not_null,
       pg_catalog.pg_get_expr(d.adbin, d.adrelid) as default_expression,
       (c.column_name is not null) as column_exists
from expected e
cross join lateral unnest(e.expected_columns) with ordinality as x(column_name, ordinal)
left join information_schema.columns c
  on c.table_schema = 'public' and c.table_name = e.table_name
 and c.column_name = x.column_name
left join pg_catalog.pg_namespace n on n.nspname = 'public'
left join pg_catalog.pg_class r on r.relnamespace = n.oid and r.relname = e.table_name
left join pg_catalog.pg_attribute a
  on a.attrelid = r.oid and a.attname = x.column_name
 and a.attnum > 0 and not a.attisdropped
left join pg_catalog.pg_attrdef d
  on d.adrelid = a.attrelid and d.adnum = a.attnum
order by e.table_name, x.ordinal;

-- 2. Table presence and RLS enabled/forced state.
with expected(table_name) as (
  values ('habits'),('habit_completions'),('xp_ledger'),('user_achievements'),
         ('completion_write_verifications'),('user_completion_time_zones'),
         ('pet_preferences'),('mood_entries'),('habit_reminders')
)
select e.table_name, (c.oid is not null) as exists,
       coalesce(c.relrowsecurity, false) as row_level_security_enabled,
       coalesce(c.relforcerowsecurity, false) as row_level_security_forced
from expected e
left join pg_catalog.pg_namespace n on n.nspname = 'public'
left join pg_catalog.pg_class c
  on c.relnamespace = n.oid and c.relname = e.table_name and c.relkind in ('r','p')
order by e.table_name;

-- 3. All constraints on the expected tables (PK, unique, FK, CHECK, etc.).
select con.conrelid::regclass::text as table_name,
       con.conname as constraint_name,
       con.contype as constraint_type,
       con.convalidated as validated,
       pg_catalog.pg_get_constraintdef(con.oid, true) as definition
from pg_catalog.pg_constraint con
join pg_catalog.pg_class rel on rel.oid = con.conrelid
join pg_catalog.pg_namespace ns on ns.oid = rel.relnamespace
where ns.nspname = 'public'
  and rel.relname in (
    'habits','habit_completions','xp_ledger','user_achievements',
    'completion_write_verifications','user_completion_time_zones',
    'pet_preferences','mood_entries','habit_reminders'
  )
order by table_name, constraint_name;

-- 4. All RLS policies on the expected tables, including USING/WITH CHECK.
select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_catalog.pg_policies
where schemaname = 'public'
  and tablename in (
    'habits','habit_completions','xp_ledger','user_achievements',
    'completion_write_verifications','user_completion_time_zones',
    'pet_preferences','mood_entries','habit_reminders'
  )
order by tablename, policyname;

-- 5. Effective role privileges required by the app (including per-column UPDATE).
with expected(table_name) as (
  values ('habits'),('habit_completions'),('xp_ledger'),('user_achievements'),
         ('completion_write_verifications'),('user_completion_time_zones'),
         ('pet_preferences'),('mood_entries'),('habit_reminders')
), roles(role_name) as (values ('anon'),('authenticated'))
select e.table_name, r.role_name,
       has_table_privilege(r.role_name, format('public.%I',e.table_name), 'SELECT') as can_select,
       has_table_privilege(r.role_name, format('public.%I',e.table_name), 'INSERT') as can_insert,
       has_table_privilege(r.role_name, format('public.%I',e.table_name), 'UPDATE') as can_update,
       has_table_privilege(r.role_name, format('public.%I',e.table_name), 'DELETE') as can_delete
from expected e cross join roles r
order by e.table_name, r.role_name;

-- Column UPDATE grants on habits are intentionally limited to these fields.
select column_name,
       has_column_privilege('authenticated', 'public.habits', column_name, 'UPDATE') as authenticated_can_update,
       has_column_privilege('anon', 'public.habits', column_name, 'UPDATE') as anon_can_update
from (values ('name'),('category'),('frequency'),('streak'),
             ('last_completed_date'),('user_id'),('id'),('created_at')) as cols(column_name)
order by column_name;

-- Also inspect explicit table ACLs (effective privileges above include inherited grants).
select n.nspname as schema_name, c.relname as table_name,
       coalesce(grantee.rolname, 'PUBLIC') as grantee,
       acl.privilege_type, acl.is_grantable
from pg_catalog.pg_class c
join pg_catalog.pg_namespace n on n.oid = c.relnamespace
cross join lateral pg_catalog.aclexplode(
  coalesce(c.relacl, pg_catalog.acldefault('r', c.relowner))
) acl
left join pg_catalog.pg_roles grantee on grantee.oid = acl.grantee
where n.nspname = 'public'
  and c.relname in (
    'habits','habit_completions','xp_ledger','user_achievements',
    'completion_write_verifications','user_completion_time_zones',
    'pet_preferences','mood_entries','habit_reminders'
  )
order by table_name, grantee, acl.privilege_type;

-- 6. RPC definitions, input names/types, return types, security mode, and ACLs.
select p.oid::regprocedure::text as identity_signature,
       p.proname as rpc_name,
       p.proargnames as argument_and_output_names,
       pg_catalog.pg_get_function_arguments(p.oid) as arguments,
       pg_catalog.pg_get_function_result(p.oid) as result,
       p.prosecdef as security_definer,
       p.proconfig as function_settings,
       pg_catalog.pg_get_userbyid(p.proowner) as owner,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') as authenticated_can_execute,
       has_function_privilege('anon', p.oid, 'EXECUTE') as anon_can_execute,
       exists (
         select 1
         from pg_catalog.aclexplode(
           coalesce(p.proacl, pg_catalog.acldefault('f', p.proowner))
         ) acl
         where acl.grantee = 0 and acl.privilege_type = 'EXECUTE'
       ) as public_can_execute,
       p.proacl as raw_acl
from pg_catalog.pg_proc p
join pg_catalog.pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in (
    'get_completion_time_zone','set_completion_time_zone',
    'get_verified_completion_count','get_verified_completion_keys',
    'record_habit_completion','claim_completion_rewards','save_pet_preferences'
  )
order by p.proname, p.oid::regprocedure::text;

-- Flag the obsolete client-date overload if it exists.
select to_regprocedure('public.record_habit_completion(uuid,date)') as obsolete_overload;

-- 7. Schema-level CREATE/USAGE rights relevant to public-object safety.
select role_name,
       has_schema_privilege(role_name, 'public', 'USAGE') as can_use_public_schema,
       has_schema_privilege(role_name, 'public', 'CREATE') as can_create_in_public
from (values ('anon'),('authenticated')) as roles(role_name)
order by role_name;

-- Explicit public-schema ACLs, including grants to the PUBLIC pseudo-role.
select n.nspname as schema_name,
       coalesce(grantee.rolname, 'PUBLIC') as grantee,
       acl.privilege_type, acl.is_grantable
from pg_catalog.pg_namespace n
cross join lateral pg_catalog.aclexplode(
  coalesce(n.nspacl, pg_catalog.acldefault('n', n.nspowner))
) acl
left join pg_catalog.pg_roles grantee on grantee.oid = acl.grantee
where n.nspname = 'public'
order by grantee, acl.privilege_type;

