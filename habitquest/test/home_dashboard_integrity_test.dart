import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit__quest/models/gamification.dart';
import 'package:habit__quest/models/account_date.dart';
import 'package:habit__quest/models/habit.dart';
import 'package:habit__quest/screens/home_screen.dart';
import 'package:habit__quest/services/habit_repository.dart';

class _HomeRepository implements HabitHomeRepository {
  final habitRequests = <Completer<List<Habit>>>[];
  final progressRequests = <Completer<GamificationProgress>>[];
  final requestedDates = <DateTime?>[];
  int completeCalls = 0;
  CompletionActionResult completionResult = const CompletionActionResult(
    streak: 1,
    rewardPending: false,
    earnedXp: 12,
    isVerified: true,
    completedOn: '2026-10-15',
  );

  @override
  String? get currentUserEmail => null;

  @override
  Future<List<Habit>> getHabits() {
    final request = Completer<List<Habit>>();
    habitRequests.add(request);
    return request.future;
  }

  @override
  Future<List<Habit>> reconcileCompletionHistory(List<Habit> habits) async =>
      habits;

  @override
  Future<bool> hasCompletionTimeZone() async => true;

  @override
  Future<GamificationProgress> getGamificationProgress({
    required Iterable<String> habitIds,
    DateTime? localDate,
  }) {
    requestedDates.add(localDate);
    final request = Completer<GamificationProgress>();
    progressRequests.add(request);
    return request.future;
  }

  @override
  Future<CompletionActionResult> completeHabit(Habit habit) async {
    completeCalls++;
    return completionResult;
  }

  @override
  Future<String?> getCompletionTimeZone() async => 'UTC';

  @override
  Future<CompletionTimeZoneSettings?> getCompletionTimeZoneSettings() async =>
      CompletionTimeZoneSettings(
        timeZone: 'UTC',
        updatedAt: DateTime.utc(2026, 1, 1),
        nextChangeAt: DateTime.utc(2026, 1, 31),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Habit _habit(String name, {String? lastCompletedDate}) => Habit(
  id: name,
  userId: 'user',
  name: name,
  category: 'Other',
  frequency: 'Daily',
  streak: 0,
  lastCompletedDate: lastCompletedDate,
);

GamificationProgress _progress(int xp) => GamificationProgress(
  totalXp: xp,
  unlockedKeys: const {},
  completedToday: null,
);

Future<void> _pumpHome(
  WidgetTester tester,
  _HomeRepository repository,
) async {
  await tester.binding.setSurfaceSize(const Size(390, 1900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(home: HomeScreen(repository: repository)),
  );
}

Future<void> _finishLoad(
  WidgetTester tester,
  _HomeRepository repository,
  int index,
  List<Habit> habits, {
  int xp = 0,
}) async {
  repository.habitRequests[index].complete(habits);
  await tester.pumpAndSettle();
  repository.progressRequests[index].complete(_progress(xp));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('loading is distinct from an empty habits state', (tester) async {
    final repository = _HomeRepository();
    await _pumpHome(tester, repository);

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('No habits yet'), findsNothing);

    await _finishLoad(tester, repository, 0, const []);
    expect(find.text('No habits yet'), findsOneWidget);
    expect(find.text('date unavailable'), findsOneWidget);
    expect(repository.requestedDates, [null]);
  });

  testWidgets('partial progress failure keeps habits and offers retry', (
    tester,
  ) async {
    final repository = _HomeRepository();
    await _pumpHome(tester, repository);
    repository.habitRequests[0].complete([_habit('Readable habit')]);
    await tester.pumpAndSettle();
    repository.progressRequests[0].completeError(StateError('offline'));
    await tester.pumpAndSettle();

    expect(find.text('Readable habit'), findsOneWidget);
    expect(
      find.textContaining('XP and achievement data failed to load'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(
      find.textContaining('Player progress is unavailable.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(repository.habitRequests, hasLength(2));
    expect(find.text('Readable habit'), findsOneWidget);

    await _finishLoad(tester, repository, 1, [_habit('Updated habit')], xp: 25);
    expect(find.text('Updated habit'), findsOneWidget);
    expect(find.text('Readable habit'), findsNothing);
    expect(find.text('25 total XP'), findsOneWidget);
  });

  testWidgets('a late old refresh cannot replace newer dashboard data', (
    tester,
  ) async {
    final repository = _HomeRepository();
    await _pumpHome(tester, repository);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(repository.habitRequests, hasLength(2));

    await _finishLoad(tester, repository, 1, [_habit('Fresh response')]);
    repository.habitRequests[0].complete([_habit('Stale response')]);
    await tester.pumpAndSettle();

    expect(find.text('Fresh response'), findsOneWidget);
    expect(find.text('Stale response'), findsNothing);
    expect(repository.requestedDates, everyElement(isNull));
  });

  testWidgets('late XP from an older refresh cannot overwrite current XP', (
    tester,
  ) async {
    final repository = _HomeRepository();
    await _pumpHome(tester, repository);
    repository.habitRequests[0].complete([_habit('Older habits')]);
    await tester.pumpAndSettle();
    expect(repository.progressRequests, hasLength(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    repository.habitRequests[1].complete([_habit('Current habits')]);
    await tester.pumpAndSettle();
    repository.progressRequests[1].complete(_progress(35));
    await tester.pumpAndSettle();

    repository.progressRequests[0].complete(_progress(900));
    await tester.pumpAndSettle();
    expect(find.text('Current habits'), findsOneWidget);
    expect(find.text('Older habits'), findsNothing);
    expect(find.text('35 total XP'), findsOneWidget);
    expect(find.text('900 total XP'), findsNothing);
  });

  testWidgets('failed refresh labels retained habits as cached and retryable', (
    tester,
  ) async {
    final repository = _HomeRepository();
    await _pumpHome(tester, repository);
    await _finishLoad(tester, repository, 0, [_habit('Cached habit')], xp: 50);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    repository.habitRequests[1].completeError(StateError('offline'));
    await tester.pumpAndSettle();

    expect(find.text('Cached habit'), findsOneWidget);
    expect(
      find.textContaining('Refresh failed. Showing previously loaded habits'),
      findsOneWidget,
    );
    expect(find.text('50 total XP'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('completion refreshes habits and player data together', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    final repository = _HomeRepository();
    await _pumpHome(tester, repository);
    await _finishLoad(
      tester,
      repository,
      0,
      [_habit('Complete me', lastCompletedDate: '2026-10-14')],
    );

    await tester.tap(
      find.bySemanticsLabel('Check completion and complete habit'),
    );
    await tester.pump();
    expect(repository.completeCalls, 1);
    expect(repository.habitRequests, hasLength(2));

    await _finishLoad(
      tester,
      repository,
      1,
      [_habit('Complete me', lastCompletedDate: '2026-10-15')],
      xp: 112,
    );
    expect(find.text('112 total XP'), findsOneWidget);
    expect(find.text('+12 XP earned'), findsOneWidget);
  });
}
