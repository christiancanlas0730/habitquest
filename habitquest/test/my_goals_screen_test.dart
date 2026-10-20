import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit__quest/models/habit.dart';
import 'package:habit__quest/models/habit_completion.dart';
import 'package:habit__quest/screens/my_goals_screen.dart';
import 'package:habit__quest/services/habit_repository.dart';

class _FakeHabitRepository implements HabitRepository {
  _FakeHabitRepository({required this.habits, this.history = const []});

  final List<Habit> habits;
  final List<HabitCompletion> history;
  bool failHabits = false;
  bool failHistory = false;
  int historyRequests = 0;

  @override
  Future<List<Habit>> getHabits() async {
    if (failHabits) throw StateError('habit load failed');
    return habits;
  }

  @override
  Future<List<HabitCompletion>> getCompletionHistory(
    Iterable<String> habitIds,
  ) async {
    historyRequests++;
    if (failHistory) throw StateError('history load failed');
    final ids = habitIds.toSet();
    return history.where((entry) => ids.contains(entry.habitId)).toList();
  }

  @override
  Future<void> addHabit({
    required String name,
    required String category,
    required String frequency,
  }) async => throw UnimplementedError();

  @override
  Future<Habit> updateHabit({
    required String id,
    required String name,
    required String category,
    required String frequency,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteHabit(String id) async => throw UnimplementedError();
}

Habit _habit({String id = 'habit-1'}) => Habit(
  id: id,
  userId: 'user-1',
  name: 'Read each day',
  category: 'Study',
  frequency: 'Every day',
  streak: 0,
);

Future<void> _pumpScreen(
  WidgetTester tester,
  _FakeHabitRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(home: MyGoalsScreen(repository: repository)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows saved habits and distinct recorded completion dates', (
    tester,
  ) async {
    final repository = _FakeHabitRepository(
      habits: [_habit()],
      history: const [
        HabitCompletion(habitId: 'habit-1', completedOn: '2026-10-14'),
        HabitCompletion(habitId: 'habit-1', completedOn: '2026-10-14'),
        HabitCompletion(habitId: 'habit-1', completedOn: '2026-10-15'),
      ],
    );

    await _pumpScreen(tester, repository);

    expect(find.text('My Goals'), findsOneWidget);
    expect(find.text('Read each day'), findsOneWidget);
    expect(find.text('Study · Every day'), findsOneWidget);
    expect(find.text('2 recorded completions'), findsOneWidget);
    expect(repository.historyRequests, 1);
  });

  testWidgets('does not turn failed history into a zero count', (tester) async {
    final repository = _FakeHabitRepository(habits: [_habit()])
      ..failHistory = true;

    await _pumpScreen(tester, repository);

    expect(find.text('Completion history unavailable'), findsOneWidget);
    expect(find.text('0 recorded completions'), findsNothing);
  });

  testWidgets('shows an empty state when no habits exist', (tester) async {
    await _pumpScreen(tester, _FakeHabitRepository(habits: const []));

    expect(find.text('No habit-based goals yet.'), findsOneWidget);
  });

  testWidgets('retry recovers after habit loading fails', (tester) async {
    final repository = _FakeHabitRepository(habits: [_habit()])
      ..failHabits = true;

    await _pumpScreen(tester, repository);

    expect(find.text('Your habit goals could not be loaded.'), findsOneWidget);
    repository.failHabits = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Read each day'), findsOneWidget);
    expect(find.text('0 recorded completions'), findsOneWidget);
  });
}
