import 'package:flutter_test/flutter_test.dart';
import 'package:habit__quest/models/completion_date_policy.dart';
import 'package:habit__quest/models/gamification.dart';
import 'package:habit__quest/models/habit.dart';
import 'package:habit__quest/models/habit_form_validation.dart';
import 'package:habit__quest/models/focus_timer_state.dart';
import 'package:habit__quest/models/habit_reminder_save.dart';
import 'package:habit__quest/models/smart_productivity.dart';
import 'package:habit__quest/screens/login_screen.dart';
import 'package:habit__quest/screens/register_screen.dart';
import 'package:habit__quest/services/app_config.dart';
import 'package:habit__quest/services/habit_service.dart';
import 'package:habit__quest/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.error, this.response});

  final Object? error;
  final AuthResponseData? response;
  int loginCalls = 0;

  @override
  Future<AuthResponseData> login(String email, String password) async {
    loginCalls++;
    if (error != null) throw error!;
    return response ?? const AuthResponseData(hasUser: true, hasSession: true);
  }

  @override
  Future<AuthResponseData> register(String email, String password) async =>
      response ?? const AuthResponseData(hasUser: true, hasSession: false);

  @override
  Future<void> logout() async {}

  @override
  User? getCurrentUser() => null;

  @override
  bool isLoggedIn() => false;
}

void main() {
  group('configuration', () {
    test('does not configure a backend by default', () {
      final config = AppConfig.fromEnvironment();
      expect(config.isConfigured, isFalse);
      expect(config.supabaseUrl, isNull);
      expect(config.supabasePublishableKey, isNull);
    });
  });

  group('form validation and safe auth messages', () {
    test('login requires both fields', () {
      expect(LoginFormValidation.error(' ', 'password'), isNotNull);
      expect(LoginFormValidation.error('person@example.test', ''), isNotNull);
      expect(
        LoginFormValidation.error('person@example.test', 'secret'),
        isNull,
      );
    });

    test('registration preserves empty-field and minimum-length messages', () {
      expect(
        RegisterFormValidation.error('', 'secret'),
        'Please complete all fields.',
      );
      expect(
        RegisterFormValidation.error('a@b.test', '12345'),
        'Password must be at least 6 characters.',
      );
      expect(RegisterFormValidation.error('a@b.test', '123456'), isNull);
    });

    test('only recognized auth codes get specific user-safe copy', () {
      expect(
        AuthService.userFacingAuthErrorCode(
          'over_email_send_rate_limit',
          fallback: 'Fallback',
        ),
        'Too many email requests. Please wait before trying again.',
      );
      expect(
        AuthService.userFacingAuthErrorCode(
          'provider-raw-message-with-email@example.test',
          fallback: 'Fallback',
        ),
        'Fallback',
      );
    });

    test('unrecognized errors use the safe fixed fallback', () {
      expect(
        AuthService.userFacingAuthError(
          StateError('server included private data'),
          fallback: 'Please try again.',
        ),
        'Please try again.',
      );
      expect(
        AuthService.userFacingAuthErrorCode(
          'email_not_confirmed',
          fallback: 'Fallback',
        ),
        'Please confirm your email address before logging in.',
      );
      expect(
        AuthService.userFacingAuthErrorCode(
          'sensitive-server-code',
          fallback: 'Fallback',
        ),
        'Fallback',
      );
    });
  });

  group('habit schedule rules', () {
    test('first off-day completion starts history, not a false streak', () {
      expect(
        _habit('Weekdays').streakAfterCompletionOn(DateTime(2026, 1, 3)),
        0,
      );
      expect(
        _habit('Weekdays').streakAfterCompletionOn(DateTime(2026, 1, 5)),
        1,
      );
      expect(
        _habit('Weekends').streakAfterCompletionOn(DateTime(2026, 1, 5)),
        0,
      );
      expect(
        _habit('Weekends').streakAfterCompletionOn(DateTime(2026, 1, 10)),
        1,
      );
    });

    test('twice-weekly streak counts successful calendar weeks, not days', () {
      final habit = _habit(
        'Twice a week',
        streak: 3,
        lastCompletedDate: '2026-01-05',
      );
      expect(habit.streakAfterCompletionOn(DateTime(2026, 1, 9)), 3);
      expect(habit.streakAfterCompletionOn(DateTime(2026, 1, 12)), 4);
      expect(habit.streakAfterCompletionOn(DateTime(2026, 1, 19)), 1);
    });

    test(
      'weekday schedules bridge weekends, but reset after missed weekdays',
      () {
        final habit = _habit(
          'Weekdays',
          streak: 3,
          lastCompletedDate: '2026-01-02',
        );
        expect(habit.streakAfterCompletionOn(DateTime(2026, 1, 5)), 4);
        expect(habit.streakAfterCompletionOn(DateTime(2026, 1, 6)), 1);
      },
    );

    test('weekly streaks use Monday boundaries', () {
      final habit = _habit(
        'Once a week',
        streak: 2,
        lastCompletedDate: '2026-01-04',
      );
      expect(habit.streakAfterCompletionOn(DateTime(2026, 1, 5)), 3);
      expect(habit.streakAfterCompletionOn(DateTime(2026, 1, 12)), 1);
    });

    test('monthly streaks cross year boundaries by calendar month', () {
      final habit = _habit(
        'Once a month',
        streak: 2,
        lastCompletedDate: '2025-12-31',
      );
      expect(habit.streakAfterCompletionOn(DateTime(2026, 1, 1)), 3);
      expect(habit.currentStreakOn(DateTime(2026, 2, 1)), 0);
      expect(habit.streakAfterCompletionOn(DateTime(2026, 2, 1)), 1);
      final january = _habit(
        'Once a month',
        streak: 3,
        lastCompletedDate: '2026-01-01',
      );
      expect(january.currentStreakOn(DateTime(2026, 2, 1)), 3);
      expect(january.streakAfterCompletionOn(DateTime(2026, 2, 1)), 4);
    });

    test('same-day completion remains idempotent', () {
      final habit = _habit(
        'Every day',
        streak: 4,
        lastCompletedDate: '2026-01-05',
      );
      expect(habit.streakAfterCompletionOn(DateTime(2026, 1, 5)), 4);
    });
  });

  test('habit form validation rejects values outside database contracts', () {
    expect(
      HabitFormValidation.error(
        name: '  ',
        category: 'Health',
        frequency: 'Every day',
      ),
      'Please enter a habit name.',
    );
    expect(
      HabitFormValidation.error(
        name: 'Read',
        category: 'Unknown',
        frequency: 'Every day',
      ),
      'Choose a valid category.',
    );
    expect(
      HabitFormValidation.error(
        name: 'Read',
        category: 'Study',
        frequency: 'Biweekly',
      ),
      'Choose a valid frequency.',
    );
    expect(
      HabitFormValidation.error(
        name: 'Read',
        category: 'Study',
        frequency: 'Once a week',
      ),
      isNull,
    );
  });

  group('focus timer state', () {
    final start = DateTime(2026, 10, 15, 10);

    test('wall-clock deadline accounts for delayed browser ticks', () {
      final running = FocusTimerState.initial().start(start);
      expect(running.remainingAt(start.add(const Duration(seconds: 70))), 1430);
      final finished = running.sync(start.add(const Duration(minutes: 25)));
      expect(finished.completed, isTrue);
      expect(finished.completedSessions, 1);
      expect(
        finished.sync(start.add(const Duration(minutes: 26))).completedSessions,
        1,
      );
    });

    test('pause and resume preserve the measured remaining duration', () {
      final running = FocusTimerState.initial().start(start);
      final paused = running.pause(start.add(const Duration(seconds: 31)));
      expect(paused.remainingSeconds, 1469);
      expect(paused.running, isFalse);
      final resumed = paused.start(start.add(const Duration(minutes: 4)));
      expect(resumed.remainingAt(start.add(const Duration(minutes: 4))), 1469);
    });

    test('a completed session restarts at the chosen duration', () {
      final completed = FocusTimerState.initial(
        durationMinutes: 10,
      ).start(start).sync(start.add(const Duration(minutes: 10)));

      final restarted = completed.start(start.add(const Duration(minutes: 11)));

      expect(restarted.running, isTrue);
      expect(restarted.completed, isFalse);
      expect(restarted.completedSessions, 1);
      expect(restarted.remainingSeconds, 600);
    });

    test('duration selection enforces supported boundaries', () {
      expect(
        () => FocusTimerState.initial().chooseDuration(0),
        throwsArgumentError,
      );
      expect(
        () => FocusTimerState.initial().chooseDuration(181),
        throwsArgumentError,
      );
      expect(
        FocusTimerState.initial().chooseDuration(180).durationSeconds,
        10800,
      );
    });
  });

  test('failed cloud reminder save does not publish optimistic state', () {
    const old = HabitReminderPreference(
      habitId: 'habit-a',
      enabled: false,
      time: '09:00',
    );
    const changed = HabitReminderPreference(
      habitId: 'habit-a',
      enabled: true,
      time: '08:30',
    );
    final result = HabitReminderSaveResult.apply(
      current: const {'habit-a': old},
      preference: changed,
      cloudPersistenceAvailable: true,
      persisted: false,
    );
    expect(result.preferences['habit-a']?.enabled, isFalse);
    expect(result.saved, isFalse);
  });

  test('timezone and completion return contracts are validated', () {
    expect(isUsableCompletionTimeZone('Asia/Singapore'), isTrue);
    expect(isUsableCompletionTimeZone('UTC'), isTrue);
    expect(isUsableCompletionTimeZone('posix/UTC'), isFalse);
    final completion = CompletionDatePolicy.parseServerCompletion({
      'completed_on': '2026-10-14',
      'is_verified': true,
      'inserted': true,
    });
    expect(completion.completedOnString, '2026-10-14');
    expect(completion.isVerified, isTrue);
    expect(completion.inserted, isTrue);
  });

  test('XP levels and quest thresholds are explicit', () {
    final progress = GamificationProgress.fromRows(
      xpRows: const [
        {'amount': 125},
      ],
      achievementRows: const [
        {'achievement_key': 'first_completion'},
      ],
      completedToday: 3,
    );
    expect(progress.level, 2);
    expect(progress.xpIntoLevel, 25);
    expect(progress.unlockedKeys, contains('first_completion'));
    expect(DailyQuestDefinition.all.map((quest) => quest.target), [1, 3]);
  });

  testWidgets('login screen shows safe errors through an injected fake', (
    tester,
  ) async {
    final auth = _FakeAuthRepository(
      error: const AuthRepositoryException('invalid_credentials'),
    );
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(authRepository: auth)),
    );
    await tester.enterText(find.byType(TextField).at(0), 'user@example.test');
    await tester.enterText(find.byType(TextField).at(1), 'incorrect');
    await tester.tap(find.text('Log in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(auth.loginCalls, 1);
    expect(
      find.text('Login failed. Check your email and password.'),
      findsOneWidget,
    );
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
