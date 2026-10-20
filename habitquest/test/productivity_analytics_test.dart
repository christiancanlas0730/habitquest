import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:habit__quest/models/habit.dart';
import 'package:habit__quest/models/habit_completion.dart';
import 'package:habit__quest/models/account_date.dart';
import 'package:habit__quest/models/productivity_analytics.dart';
import 'package:habit__quest/models/smart_productivity.dart';
import 'package:habit__quest/screens/focus_timer_screen.dart';

void main() {
  final dateSource = AccountDateSource.fromSettings(
    CompletionTimeZoneSettings(
      timeZone: 'UTC',
      updatedAt: DateTime.utc(2026, 1, 1),
      nextChangeAt: DateTime.utc(2026, 1, 31),
    ),
    clock: () => DateTime.utc(2026, 10, 15),
  );

  group('productivity period summaries', () {
    test('weekly totals and completion rate use saved daily records', () {
      final habit = _habit('daily', 'Every day', DateTime(2026, 10, 5));
      final summary = ProductivityPeriodSummary.calculate(
        habits: [habit],
        completions: const [
          HabitCompletion(habitId: 'daily', completedOn: '2026-10-05'),
          HabitCompletion(habitId: 'daily', completedOn: '2026-10-07'),
        ],
        start: DateTime(2026, 10, 5),
        end: DateTime(2026, 10, 11),
        dateSource: dateSource,
      );

      expect(summary.recordedCompletions, 2);
      expect(summary.expectedCompletions, 7);
      expect(summary.successfulOpportunities, 2);
      expect(summary.completionRate, closeTo(2 / 7, 0.0001));
      expect(summary.dailyCompletions, [1, 0, 1, 0, 0, 0, 0]);
    });

    test('once a week uses Monday-to-Sunday boundaries and caps the rate', () {
      final habit = _habit('weekly', 'Once a week', DateTime(2026, 10, 5));
      final summary = ProductivityPeriodSummary.calculate(
        habits: [habit],
        completions: const [
          HabitCompletion(habitId: 'weekly', completedOn: '2026-10-05'),
          HabitCompletion(habitId: 'weekly', completedOn: '2026-10-11'),
        ],
        start: DateTime(2026, 10, 5),
        end: DateTime(2026, 10, 11),
        dateSource: dateSource,
      );

      expect(summary.recordedCompletions, 2);
      expect(summary.expectedCompletions, 1);
      expect(summary.successfulOpportunities, 1);
      expect(summary.completionRate, 1);
    });

    test('monthly habit progress counts the current calendar month', () {
      final habit = _habit('monthly', 'Once a month', DateTime(2026, 9, 1));
      final summary = ProductivityPeriodSummary.calculate(
        habits: [habit],
        completions: const [
          HabitCompletion(habitId: 'monthly', completedOn: '2026-10-03'),
        ],
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 11),
        dateSource: dateSource,
      );

      expect(summary.expectedCompletions, 1);
      expect(summary.successfulOpportunities, 1);
      expect(summary.completionRate, 1);
    });
  });

  test(
    'private journal and reminder models keep user/date preference fields',
    () {
      final mood = const MoodEntry(
        entryDate: '2026-10-11',
        mood: 'good',
        note: 'A short note',
      ).toMap('user-a');
      final reminder = const HabitReminderPreference(
        habitId: 'habit-a',
        enabled: true,
        time: '08:30',
      ).toMap('user-a');

      expect(mood, {
        'user_id': 'user-a',
        'entry_date': '2026-10-11',
        'mood': 'good',
        'note': 'A short note',
      });
      expect(reminder['user_id'], 'user-a');
      expect(reminder['habit_id'], 'habit-a');
      expect(reminder['enabled'], isTrue);
      expect(reminder['reminder_time'], '08:30');
    },
  );

  testWidgets('focus timer can start, pause, resume, and reset', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: FocusTimerScreen()));

    await tester.tap(find.text('Start'));
    await tester.pump();
    expect(find.text('Pause'), findsOneWidget);

    await tester.tap(find.text('Pause'));
    await tester.pump();
    expect(find.text('Resume'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pump();
    expect(find.text('Pause'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(find.text('Start'), findsOneWidget);
  });
}

Habit _habit(String id, String frequency, DateTime createdAt) => Habit(
  id: id,
  userId: 'user',
  name: 'Test $id',
  category: 'Personal',
  frequency: frequency,
  streak: 0,
  createdAt: createdAt,
);
