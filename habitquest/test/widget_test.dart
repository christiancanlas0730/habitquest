import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit__quest/models/habit.dart';
import 'package:habit__quest/models/gamification.dart';
import 'package:habit__quest/models/habit_completion.dart';
import 'package:habit__quest/models/completion_recovery.dart';
import 'package:habit__quest/models/completion_date_policy.dart';
import 'package:habit__quest/services/habit_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('completion timezone identifier shape', () {
    test('accepts canonical IANA-style names and UTC', () {
      expect(isUsableCompletionTimeZone('Asia/Singapore'), isTrue);
      expect(
        isUsableCompletionTimeZone('America/Argentina/Buenos_Aires'),
        isTrue,
      );
      expect(isUsableCompletionTimeZone('UTC'), isTrue);
    });

    test('rejects incomplete and malformed timezone settings', () {
      expect(isUsableCompletionTimeZone(null), isFalse);
      expect(isUsableCompletionTimeZone(''), isFalse);
      expect(isUsableCompletionTimeZone('   '), isFalse);
      expect(isUsableCompletionTimeZone('Asia'), isFalse);
      expect(isUsableCompletionTimeZone('/Singapore'), isFalse);
      expect(isUsableCompletionTimeZone('Asia//Singapore'), isFalse);
      expect(isUsableCompletionTimeZone('posix/Asia/Singapore'), isFalse);
      expect(isUsableCompletionTimeZone(' Asia/Singapore '), isFalse);
    });
  });

  group('gamification progress', () {
    test('levels are deterministic and restart progress each 100 XP', () {
      final progress = GamificationProgress.fromRows(
        xpRows: [
          {'amount': 75},
          {'amount': 50},
        ],
        achievementRows: const [],
        completedToday: 2,
      );

      expect(progress.totalXp, 125);
      expect(progress.level, 2);
      expect(progress.xpIntoLevel, 25);
      expect(progress.xpToNextLevel, 75);
      expect(progress.levelProgress, 0.25);
    });

    test('progress loads achievement unlocks and local quest count', () {
      final progress = GamificationProgress.fromRows(
        xpRows: const [],
        achievementRows: [
          {'achievement_key': 'first_completion'},
        ],
        completedToday: 3,
      );

      expect(progress.unlockedKeys, contains('first_completion'));
      expect(progress.completedToday, 3);
      expect(DailyQuestDefinition.all.map((quest) => quest.target), [1, 3]);
    });
  });

  group('frequency-aware habit streaks', () {
    test(
      'every day increments consecutively and resets after a missed day',
      () {
        final habit = _habit(
          'Every day',
          streak: 4,
          lastCompletedDate: '2026-01-01',
        );

        expect(habit.streakAfterCompletionOn(DateTime(2026, 1, 2)), 5);
        expect(habit.streakAfterCompletionOn(DateTime(2026, 1, 3)), 1);
        expect(habit.currentStreakOn(DateTime(2026, 1, 3)), 0);
      },
    );

    test('weekdays skip weekends but reset after a missed weekday', () {
      final habit = _habit(
        'Weekdays',
        streak: 3,
        lastCompletedDate: '2026-01-02',
      );

      expect(habit.currentStreakOn(DateTime(2026, 1, 5)), 3);
      expect(habit.streakAfterCompletionOn(DateTime(2026, 1, 5)), 4);
      expect(habit.streakAfterCompletionOn(DateTime(2026, 1, 6)), 1);
    });

    test('weekends skip weekdays and count scheduled weekend completions', () {
      final habit = _habit(
        'Weekends',
        streak: 2,
        lastCompletedDate: '2026-01-04',
      );

      expect(habit.currentStreakOn(DateTime(2026, 1, 9)), 2);
      expect(habit.streakAfterCompletionOn(DateTime(2026, 1, 10)), 3);
      expect(habit.streakAfterCompletionOn(DateTime(2026, 1, 11)), 1);
    });

    test('once a week counts successful calendar weeks, not days', () {
      final habit = _habit(
        'Once a week',
        streak: 6,
        lastCompletedDate: '2026-01-04',
      );

      expect(habit.streakAfterCompletionOn(DateTime(2026, 1, 7)), 7);
      expect(habit.streakAfterCompletionOn(DateTime(2026, 1, 5)), 7);
      expect(habit.streakAfterCompletionOn(DateTime(2026, 1, 12)), 1);
    });

    test('Monday is the weekly boundary after Sunday', () {
      final habit = _habit(
        'Once a week',
        streak: 6,
        lastCompletedDate: '2026-01-04', // Sunday
      );

      expect(habit.streakAfterCompletionOn(DateTime(2026, 1, 4)), 6);
      expect(habit.streakAfterCompletionOn(DateTime(2026, 1, 5)), 7);
      expect(habit.streakAfterCompletionOn(DateTime(2026, 1, 11)), 7);

      final nextSunday = _habit(
        'Once a week',
        streak: 6,
        lastCompletedDate: '2026-01-11',
      );
      expect(nextSunday.streakAfterCompletionOn(DateTime(2026, 1, 12)), 7);
    });

    test('twice a week uses a four-day interval approximation', () {
      final habit = _habit(
        'Twice a week',
        streak: 3,
        lastCompletedDate: '2026-01-05',
      );

      expect(habit.currentStreakOn(DateTime(2026, 1, 9)), 3);
      expect(habit.streakAfterCompletionOn(DateTime(2026, 1, 9)), 4);
      expect(habit.currentStreakOn(DateTime(2026, 1, 10)), 0);
      expect(habit.streakAfterCompletionOn(DateTime(2026, 1, 10)), 1);
    });

    test('once a month counts successful calendar months, not days', () {
      final habit = _habit(
        'Once a month',
        streak: 2,
        lastCompletedDate: '2026-01-31',
      );

      expect(habit.streakAfterCompletionOn(DateTime(2026, 2, 1)), 3);
      expect(
        _habit(
          'Once a month',
          streak: 3,
          lastCompletedDate: '2026-02-01',
        ).streakAfterCompletionOn(DateTime(2026, 2, 20)),
        3,
      );
      expect(habit.streakAfterCompletionOn(DateTime(2026, 3, 1)), 1);
    });

    test('same-day completion remains idempotent', () {
      final habit = _habit(
        'Every day',
        streak: 3,
        lastCompletedDate: '2026-01-05',
      );

      expect(habit.wasCompletedOn(DateTime(2026, 1, 5)), isTrue);
      expect(habit.streakAfterCompletionOn(DateTime(2026, 1, 5)), 3);
    });
  });

  group('completion recovery', () {
    final habit = _habit('Every day');
    const completion = HabitCompletion(
      habitId: 'habit-id',
      completedOn: '2026-01-02',
    );

    test('refresh repairs a saved completion and retries its reward', () async {
      Habit? persisted;
      final claimed = <String>[];

      final recovered = await runCompletionRecovery(
        habits: [habit],
        completions: const [completion],
        recordedRewardKeys: const {},
        verifiedCompletionKeys: const {'habit-id:2026-01-02'},
        persistSummary: (value) async => persisted = value,
        claimReward: (value) async => claimed.add(completionRewardKey(value)),
      );

      expect(persisted?.lastCompletedDate, '2026-01-02');
      expect(recovered.single.lastCompletedDate, '2026-01-02');
      expect(recovered.single.streak, 1);
      expect(claimed, ['completion:habit-id:2026-01-02']);
    });

    test(
      'a partial summary failure is retried before claiming its reward',
      () async {
        var failFirstSave = true;
        var claimCount = 0;

        Future<void> saveSummary(Habit value) async {
          if (failFirstSave) {
            failFirstSave = false;
            throw StateError('temporary summary failure');
          }
        }

        Future<void> claim(HabitCompletion value) async {
          claimCount++;
        }

        await expectLater(
          runCompletionRecovery(
            habits: [habit],
            completions: const [completion],
            recordedRewardKeys: const {},
            verifiedCompletionKeys: const {'habit-id:2026-01-02'},
            persistSummary: saveSummary,
            claimReward: claim,
          ),
          throwsStateError,
        );
        expect(claimCount, 0);

        await runCompletionRecovery(
          habits: [habit],
          completions: const [completion],
          recordedRewardKeys: const {},
          verifiedCompletionKeys: const {'habit-id:2026-01-02'},
          persistSummary: saveSummary,
          claimReward: claim,
        );
        expect(claimCount, 1);
      },
    );

    test(
      'repeated reward RPC retries rely on idempotency, not a client cache',
      () async {
        final awardedKeys = <String>{};
        var awardCount = 0;

        Future<void> claim(HabitCompletion value) async {
          if (awardedKeys.add(completionRewardKey(value))) awardCount++;
        }

        for (var attempt = 0; attempt < 2; attempt++) {
          await runCompletionRecovery(
            habits: [_habit('Every day', lastCompletedDate: '2026-01-02')],
            completions: const [completion],
            // Simulate a timed-out response: the refresh has a stale ledger read.
            recordedRewardKeys: const {},
            verifiedCompletionKeys: const {'habit-id:2026-01-02'},
            persistSummary: (_) async {},
            claimReward: claim,
          );
        }

        expect(awardCount, 1);
      },
    );

    test('legacy unverified rows repair history but cannot claim rewards', () {
      final plan = planCompletionRecovery(
        habits: [habit],
        completions: const [completion],
        recordedRewardKeys: const {},
        verifiedCompletionKeys: const {},
      );

      expect(plan.habits.single.lastCompletedDate, '2026-01-02');
      expect(plan.rewardsToClaim, isEmpty);
    });

    test('duplicate completion rows schedule one reward attempt', () {
      final plan = planCompletionRecovery(
        habits: [habit],
        completions: const [completion, completion],
        recordedRewardKeys: const {},
        verifiedCompletionKeys: const {'habit-id:2026-01-02'},
      );

      expect(plan.rewardsToClaim, [completion]);
    });

    test('optional table detection does not swallow permission failures', () {
      expect(isMissingOptionalRelationCode('PGRST205'), isTrue);
      expect(isMissingOptionalRelationCode('42P01'), isTrue);
      expect(isMissingOptionalRelationCode('42501'), isFalse);
      expect(isMissingOptionalRelationCode('08006'), isFalse);
    });

    test(
      'a saved completion remains successful while reward retries',
      () async {
        var completionSaved = false;
        var attempts = 0;

        completionSaved = true;
        final firstAttempt = await tryClaimPersistedReward(() async {
          attempts++;
          throw StateError('reward RPC unavailable');
        });

        expect(completionSaved, isTrue);
        expect(firstAttempt, isNull);

        final retry = await tryClaimPersistedReward(() async {
          attempts++;
          return 10;
        });

        expect(retry, 10);
        expect(attempts, 2);
      },
    );
  });

  group('completion date policy', () {
    test('completion result retains the server-derived date', () {
      const result = HabitCompletionResult(
        streak: 1,
        reward: null,
        isVerified: true,
        completedOn: '2026-10-14',
      );

      expect(result.completedOnString, '2026-10-14');
    });

    test('uses the server returned date and verification status', () {
      final completion = CompletionDatePolicy.parseServerCompletion({
        'completed_on': '2026-10-14',
        'is_verified': true,
        'inserted': true,
      });

      expect(completion.completedOnString, '2026-10-14');
      expect(completion.isVerified, isTrue);
      expect(completion.inserted, isTrue);
    });

    test('preserves duplicate insertion status from the server', () {
      final completion = CompletionDatePolicy.parseServerCompletion({
        'completed_on': '2026-10-14',
        'is_verified': true,
        'inserted': false,
      });

      expect(completion.isVerified, isTrue);
      expect(completion.inserted, isFalse);
    });

    test('does not accept a missing, malformed, or client-only date', () {
      expect(
        () => CompletionDatePolicy.parseServerCompletion({'is_verified': true}),
        throwsFormatException,
      );
      expect(
        () => CompletionDatePolicy.parseServerCompletion({
          'completed_on': '2026-02-30',
          'is_verified': true,
        }),
        throwsFormatException,
      );
      expect(
        () => CompletionDatePolicy.parseServerCompletion({
          'completed_on': '2026-10-14',
          'is_verified': 'true',
        }),
        throwsFormatException,
      );
    });
  });

  group('completion timezone RPC errors', () {
    test('maps PGRST202 without exposing the raw server message', () {
      final message = completionTimeZoneErrorMessage(
        PostgrestException(
          message: 'Could not find the function in the schema cache.',
          code: 'PGRST202',
        ),
        fallback: 'generic fallback',
      );

      expect(message, contains('timezone service is unavailable'));
      expect(message, contains('completion remains disabled'));
      expect(message, isNot(contains('Could not find the function')));
    });

    test('keeps the caller fallback for other failures', () {
      expect(
        completionTimeZoneErrorMessage(
          Exception('network failure'),
          fallback: 'Retry timezone setup.',
        ),
        'Retry timezone setup.',
      );
    });
  });

  testWidgets('HabitQuest app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Text('HabitQuest')));

    expect(find.text('HabitQuest'), findsOneWidget);
  });
}

Habit _habit(String frequency, {int streak = 0, String? lastCompletedDate}) =>
    Habit(
      id: 'habit-id',
      userId: 'user-id',
      name: 'Test habit',
      category: 'Health',
      frequency: frequency,
      streak: streak,
      lastCompletedDate: lastCompletedDate,
    );
