import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase_clean_project/supabase/migrations/20261015020000_gamification_timezone_pet.sql',
  ).readAsStringSync();
  final coreMigration = File(
    'supabase_clean_project/supabase/migrations/20261015010000_initial_habit_core.sql',
  ).readAsStringSync();
  final recordStart = migration.indexOf(
    'create function public.record_habit_completion',
  );
  final claimStart = migration.indexOf(
    'create or replace function public.claim_completion_rewards',
  );
  final recordFunction = migration.substring(recordStart, claimStart);
  final claimFunction = migration.substring(claimStart);

  group('server-derived completion migration guards', () {
    test('derives the date from server time and stored IANA timezone', () {
      expect(
        recordFunction,
        contains(
          'pg_catalog.timezone(v_time_zone, pg_catalog.transaction_timestamp())::date',
        ),
      );
      expect(recordFunction, contains('pg_catalog.pg_timezone_names'));
      expect(recordFunction, isNot(contains('p_completed_on')));
      expect(recordFunction, isNot(contains('UTC today')));
    });

    test('rejects missing and invalid timezone settings', () {
      expect(migration, contains('A valid IANA timezone is required'));
      expect(
        recordFunction,
        contains('Completion timezone is missing or invalid'),
      );
      expect(recordFunction, contains('if v_time_zone is null'));
      expect(
        recordFunction,
        contains("pg_catalog.strpos(v_time_zone, '/') = 0"),
      );
      expect(recordFunction, contains('from pg_catalog.pg_timezone_names z'));
      expect(recordFunction, contains('where z.name = v_time_zone'));
    });

    test('allows timezone preference changes no more than every 30 days', () {
      expect(migration, contains("interval '30 days'"));
      expect(
        migration,
        contains('Timezone changes are limited to once every 30 days'),
      );
      expect(migration, contains('for update'));
    });

    test('rejects unowned habit identifiers and keeps inserts private', () {
      expect(
        recordFunction,
        contains('h.id = p_habit_id and h.user_id = v_user_id'),
      );
      expect(recordFunction, contains("using errcode = '42501'"));
      expect(
        migration,
        contains(
          'revoke all on table public.habit_completions from anon, authenticated, public',
        ),
      );
      expect(
        migration,
        contains(
          'grant select on table public.habit_completions to authenticated',
        ),
      );
      expect(
        coreMigration,
        isNot(contains('Users can create completions for their own habits')),
      );
    });

    test('duplicate requests do not upgrade unverified history', () {
      expect(
        recordFunction,
        contains('on conflict (habit_id, completed_on) do nothing'),
      );
      expect(recordFunction, contains('if v_inserted > 0 then'));
      expect(recordFunction, contains('select exists ('));
      expect(recordFunction, contains("'is_verified', v_verified"));
    });

    test('completion and verification writes share one RPC transaction', () {
      final completionInsert = recordFunction.indexOf(
        'insert into public.habit_completions',
      );
      final verificationInsert = recordFunction.indexOf(
        'insert into public.completion_write_verifications',
      );
      expect(completionInsert, greaterThanOrEqualTo(0));
      expect(verificationInsert, greaterThan(completionInsert));
      expect(recordFunction, isNot(contains('exception when')));
    });

    test('rewards require verification and retain unique idempotency keys', () {
      expect(
        claimFunction,
        contains('from public.completion_write_verifications v'),
      );
      expect(claimFunction, contains('if not found then'));
      expect(
        claimFunction,
        contains(
          "'completion:' || p_habit_id::text || ':' || p_completed_on::text",
        ),
      );
      expect(
        claimFunction,
        contains('on conflict (user_id, idempotency_key) do nothing'),
      );
      expect(claimFunction, contains("'quest:one:'"));
      expect(claimFunction, contains("'quest:three:'"));
      expect(claimFunction, contains("'achievement:first_completion'"));
    });

    test('does not backfill or rewrite existing completion history', () {
      expect(
        coreMigration + migration,
        isNot(
          contains('insert into public.completion_write_verifications\nselect'),
        ),
      );
      expect(migration, contains('time_zone text'));
    });
  });
}
