import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit__quest/models/account_date.dart';
import 'package:habit__quest/models/habit.dart';
import 'package:habit__quest/models/habit_completion.dart';
import 'package:habit__quest/screens/calendar_history_screen.dart';
import 'package:habit__quest/screens/statistics_screen.dart';
import 'package:habit__quest/services/habit_repository.dart';

class _BrowserFake implements HabitBrowserRepository, AccountDateRepository {
  _BrowserFake({
    required this.snapshot,
    this.timeZoneSettings,
    this.failTimeZoneLoad = false,
  });

  final CompletionHistorySnapshot snapshot;
  final CompletionTimeZoneSettings? timeZoneSettings;
  final bool failTimeZoneLoad;

  @override
  Future<CompletionTimeZoneSettings?> getCompletionTimeZoneSettings() async {
    if (failTimeZoneLoad) throw StateError('timezone unavailable');
    return timeZoneSettings;
  }

  @override
  Future<CompletionHistorySnapshot> loadCompletionHistory() async => snapshot;

  @override
  Future<List<Habit>> getHabits() async => snapshot.habits;

  @override
  Future<List<HabitCompletion>> getCompletionHistory(
    Iterable<String> habitIds,
  ) async => snapshot.completions;

  @override
  Future<void> addHabit({
    required String name,
    required String category,
    required String frequency,
  }) async {}

  @override
  Future<Habit> updateHabit({
    required String id,
    required String name,
    required String category,
    required String frequency,
  }) async => snapshot.habits.single;

  @override
  Future<void> deleteHabit(String id) async {}
}

Habit _habit({DateTime? createdAt}) => Habit(
  id: 'habit-1',
  userId: 'user-1',
  name: 'Read',
  category: 'Study',
  frequency: 'Every day',
  streak: 0,
  createdAt: createdAt,
);

CompletionTimeZoneSettings _settings(String zone) =>
    CompletionTimeZoneSettings(
      timeZone: zone,
      updatedAt: DateTime.utc(2025, 1, 1),
      nextChangeAt: DateTime.utc(2025, 1, 31),
    );

void main() {
  testWidgets('calendar selects account-local today and marks server history', (
    tester,
  ) async {
    final repository = _BrowserFake(
      snapshot: CompletionHistorySnapshot(
        habits: [_habit()],
        completions: const [
          HabitCompletion(habitId: 'habit-1', completedOn: '2026-01-01'),
        ],
      ),
      timeZoneSettings: _settings('Asia/Singapore'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CalendarHistoryScreen(
          repository: repository,
          accountClock: () => DateTime.utc(2026, 1, 1, 0, 30),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('January 2026'), findsOneWidget);
    expect(find.text('January 1, 2026'), findsOneWidget);
    expect(find.text('1 habit'), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
  });

  testWidgets('calendar uses account-local today when history is empty', (
    tester,
  ) async {
    final repository = _BrowserFake(
      snapshot: const CompletionHistorySnapshot(habits: [], completions: []),
      timeZoneSettings: _settings('America/Los_Angeles'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CalendarHistoryScreen(
          repository: repository,
          accountClock: () => DateTime.utc(2026, 1, 1, 0, 30),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('December 2025'), findsOneWidget);
    expect(find.text('December 31, 2025'), findsOneWidget);
    expect(find.text('January 2000'), findsNothing);
  });

  testWidgets('calendar has no invented date without timezone or history', (
    tester,
  ) async {
    final repository = _BrowserFake(
      snapshot: const CompletionHistorySnapshot(habits: [], completions: []),
    );
    await tester.pumpWidget(
      MaterialApp(home: CalendarHistoryScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Calendar date is unavailable.'),
      findsOneWidget,
    );
    expect(find.text('January 2000'), findsNothing);
  });

  testWidgets('statistics leaves date metrics unavailable without timezone', (
    tester,
  ) async {
    final repository = _BrowserFake(
      snapshot: const CompletionHistorySnapshot(habits: [], completions: []),
    );
    await tester.pumpWidget(
      MaterialApp(home: StatisticsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Today’s completion is unavailable until the account timezone and habit creation dates can be resolved.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Weekly and monthly summaries are unavailable until the account date and habit creation dates can be resolved.',
      ),
      findsOneWidget,
    );
    expect(find.text('0'), findsNWidgets(2));
    expect(find.text('Create habits to see how they’re grouped here.'),
        findsOneWidget);
  });

  testWidgets('statistics uses account-local today and recorded dates', (
    tester,
  ) async {
    final repository = _BrowserFake(
      snapshot: CompletionHistorySnapshot(
        habits: [_habit(createdAt: DateTime.utc(2025, 12, 1))],
        completions: const [
          HabitCompletion(habitId: 'habit-1', completedOn: '2026-01-01'),
        ],
      ),
      timeZoneSettings: _settings('Asia/Singapore'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StatisticsScreen(
          repository: repository,
          accountClock: () => DateTime.utc(2026, 1, 1, 0, 30),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Today: 1 of 1 habits (100%). 0 remaining.'),
        findsOneWidget);
    expect(find.textContaining('This week: 1 of 4 scheduled'), findsOneWidget);
    expect(find.text('Unavailable'), findsNothing);
  });

  testWidgets('recorded totals remain when timezone lookup partially fails', (
    tester,
  ) async {
    final repository = _BrowserFake(
      snapshot: CompletionHistorySnapshot(
        habits: [_habit(createdAt: DateTime.utc(2026, 1, 1))],
        completions: const [
          HabitCompletion(habitId: 'habit-1', completedOn: '2026-01-01'),
        ],
      ),
      failTimeZoneLoad: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StatisticsScreen(
          repository: repository,
          accountClock: () => DateTime.utc(2026, 1, 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(find.textContaining('Recorded totals include available history.'),
        findsOneWidget);
    expect(find.textContaining('unavailable until the account date'),
        findsWidgets);
  });

  testWidgets('empty history with timezone yields zero metrics', (tester) async {
    final repository = _BrowserFake(
      snapshot: const CompletionHistorySnapshot(habits: [], completions: []),
      timeZoneSettings: _settings('UTC'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StatisticsScreen(
          repository: repository,
          accountClock: () => DateTime.utc(2026, 1, 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Today: 0 of 0 habits (0%). 0 remaining.'),
        findsOneWidget);
    expect(find.textContaining('This week: 0 of 0 scheduled'), findsOneWidget);
  });
}
