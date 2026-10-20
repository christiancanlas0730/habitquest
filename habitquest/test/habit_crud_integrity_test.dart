import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit__quest/models/habit.dart';
import 'package:habit__quest/models/habit_completion.dart';
import 'package:habit__quest/models/completion_date_policy.dart';
import 'package:habit__quest/models/request_generation.dart';
import 'package:habit__quest/screens/add_habit_screen.dart';
import 'package:habit__quest/screens/edit_habit_screen.dart';
import 'package:habit__quest/services/habit_repository.dart';
import 'package:habit__quest/widgets/premium_ui.dart';

class _FakeHabitRepository implements HabitRepository, HabitFormRepository {
  Completer<void>? addGate;
  Completer<void>? deleteGate;
  Completer<Habit>? updateGate;
  int addCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;
  String? updatedCategory;

  @override
  Future<void> addHabit({
    required String name,
    required String category,
    required String frequency,
  }) {
    addCalls++;
    return addGate?.future ?? Future<void>.error(StateError('save failed'));
  }

  @override
  Future<Habit> updateHabit({
    required String id,
    required String name,
    required String category,
    required String frequency,
  }) {
    updateCalls++;
    updatedCategory = category;
    return updateGate?.future ?? Future<Habit>.error(StateError('save failed'));
  }

  @override
  Future<void> deleteHabit(String id) {
    deleteCalls++;
    return deleteGate?.future ?? Future<void>.error(StateError('delete failed'));
  }

  @override
  Future<List<Habit>> getHabits() async => [];

  @override
  Future<List<HabitCompletion>> getCompletionHistory(
    Iterable<String> habitIds,
  ) async => [];
}

Habit _habit({String category = 'Other'}) => Habit(
  id: 'habit-1',
  userId: 'user-1',
  name: 'Read',
  category: category,
  frequency: 'Every day',
  streak: 0,
);

void main() {
  testWidgets('create ignores duplicate submits and remains retryable on error', (
    tester,
  ) async {
    final repository = _FakeHabitRepository()
      ..addGate = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(home: AddHabitScreen(repository: repository)),
    );
    await tester.enterText(find.byType(TextField).first, 'Walk');

    await tester.tap(find.text('Create habit'));
    await tester.pump();
    await tester.tap(find.byType(GradientActionButton));
    expect(repository.addCalls, 1);

    repository.addGate!.completeError(StateError('offline'));
    await tester.pump();
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Walk',
    );
    expect(find.text('Failed to add habit. Please try again.'), findsOneWidget);

    repository.addGate = null;
    await tester.tap(find.text('Create habit'));
    await tester.pumpAndSettle();
    expect(repository.addCalls, 2);
  });

  testWidgets('edit preserves Other and failed save can be retried', (
    tester,
  ) async {
    final repository = _FakeHabitRepository()
      ..updateGate = Completer<Habit>();
    await tester.pumpWidget(
      MaterialApp(
        home: EditHabitScreen(habit: _habit(), repository: repository),
      ),
    );

    await tester.tap(find.text('Save changes'));
    await tester.pump();
    await tester.tap(find.byType(GradientActionButton));
    expect(repository.updateCalls, 1);
    expect(repository.updatedCategory, 'Other');

    repository.updateGate!.completeError(StateError('offline'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Failed to update habit. Please try again.'), findsOneWidget);

    repository.updateGate = null;
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    expect(repository.updateCalls, 2);
    expect(repository.updatedCategory, 'Other');
  });

  testWidgets('delete failure returns to an actionable state for retry', (
    tester,
  ) async {
    final repository = _FakeHabitRepository()
      ..deleteGate = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: EditHabitScreen(habit: _habit(), repository: repository),
      ),
    );

    await tester.tap(find.text('Delete habit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pump();
    expect(repository.deleteCalls, 1);

    repository.deleteGate!.completeError(StateError('offline'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Failed to delete habit. Please try again.'), findsOneWidget);

    repository.deleteGate = null;
    await tester.tap(find.text('Delete habit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(repository.deleteCalls, 2);
  });

  test('completion history deduplicates repeated habit/date keys', () {
    final rows = deduplicateHabitCompletions([
      const HabitCompletion(habitId: 'a', completedOn: '2026-10-14'),
      const HabitCompletion(habitId: 'a', completedOn: '2026-10-14'),
      const HabitCompletion(habitId: 'b', completedOn: '2026-10-14'),
      const HabitCompletion(habitId: 'a', completedOn: '2026-10-15'),
    ]);

    expect(rows, hasLength(3));
    expect(rows.map((row) => '${row.habitId}:${row.completedOn}').toList(), [
      'a:2026-10-14',
      'b:2026-10-14',
      'a:2026-10-15',
    ]);
  });

  test('inclusive history pages advance only after full pages', () async {
    final ranges = <(int, int)>[];
    final rows = await fetchInclusivePages<int>(
      pageSize: 2,
      fetchPage: (from, to) async {
        ranges.add((from, to));
        return switch (from) {
          0 => [1, 2],
          2 => [2, 3], // A repeated row does not affect paging termination.
          _ => <int>[],
        };
      },
    );

    expect(ranges, [(0, 1), (2, 3), (4, 5)]);
    expect(rows, [1, 2, 2, 3]);
  });

  test('history paging handles empty and short pages and propagates failures', () async {
    var emptyCalls = 0;
    expect(
      await fetchInclusivePages<int>(
        pageSize: 500,
        fetchPage: (from, to) async {
          emptyCalls++;
          return [];
        },
      ),
      isEmpty,
    );
    expect(emptyCalls, 1);

    expect(
      await fetchInclusivePages<int>(
        pageSize: 3,
        fetchPage: (from, to) async => [7],
      ),
      [7],
    );
    await expectLater(
      fetchInclusivePages<int>(
        pageSize: 1,
        fetchPage: (from, to) async => throw StateError('page failed'),
      ),
      throwsStateError,
    );
  });

  test('stale request generations cannot become current again', () async {
    final requests = RequestGeneration();
    final older = requests.begin();
    final newer = requests.begin();
    final responses = <String, Completer<String>>{
      'older': Completer<String>(),
      'newer': Completer<String>(),
    };
    String? visible;

    final olderLoad = responses['older']!.future.then((value) {
      if (requests.isCurrent(older)) visible = value;
    });
    final newerLoad = responses['newer']!.future.then((value) {
      if (requests.isCurrent(newer)) visible = value;
    });
    responses['newer']!.complete('new');
    await newerLoad;
    responses['older']!.complete('old');
    await olderLoad;

    expect(visible, 'new');
  });

  test('completion dates preserve server calendar day without conversion', () {
    expect(
      HabitCompletion.fromMap({
        'habit_id': 'habit-1',
        'completed_on': '2026-01-01',
      }).completedOn,
      '2026-01-01',
    );
    expect(
      HabitCompletion.fromMap({
        'habit_id': 'habit-1',
        'completed_on': '2026-01-01T00:30:00+14:00',
      }).completedOn,
      '2026-01-01',
    );
    expect(
      () => HabitCompletion.fromMap({
        'habit_id': 'habit-1',
        'completed_on': '2026-02-30',
      }),
      throwsFormatException,
    );
    expect(
      () => HabitCompletion.fromMap({
        'habit_id': 'habit-1',
        'completed_on': '2026-01-01T99:70:00+14:00',
      }),
      throwsFormatException,
    );
    expect(
      () => CompletionDatePolicy.parseServerCompletion({
        'completed_on': '2026-01-01T00:30:00+14:00',
        'is_verified': true,
        'inserted': true,
      }),
      throwsFormatException,
    );
  });
}
