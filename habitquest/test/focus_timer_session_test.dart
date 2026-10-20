import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit__quest/models/focus_timer_state.dart';
import 'package:habit__quest/screens/focus_timer_screen.dart';
import 'package:habit__quest/services/focus_timer_session.dart';

void main() {
  group('FocusTimerSession', () {
    test('pause freezes remaining time and resume starts a new deadline', () {
      var now = DateTime.utc(2026, 10, 15, 12);
      final session = FocusTimerSession(clock: () => now);

      session.start();
      now = now.add(const Duration(minutes: 1));
      session.pause();
      expect(session.state.remainingSeconds, 24 * 60);

      now = now.add(const Duration(hours: 3));
      expect(session.remainingSecondsAtNow(), 24 * 60);
      session.start();
      now = now.add(const Duration(seconds: 30));
      expect(session.remainingSecondsAtNow(), 23 * 60 + 30);
    });

    test('sync after an elapsed deadline records completion only once', () {
      var now = DateTime.utc(2026, 10, 15, 12);
      final session = FocusTimerSession(
        clock: () => now,
        initialState: FocusTimerState.initial(durationMinutes: 1),
      );
      session.start();
      now = now.add(const Duration(minutes: 2));

      session.sync();
      expect(session.state.completed, isTrue);
      expect(session.state.completedSessions, 1);
      session.sync();
      expect(session.state.completedSessions, 1);
    });

    test('duration changes reset the idle countdown', () {
      final session = FocusTimerSession();
      session.chooseDuration(45);

      expect(session.state.durationSeconds, 45 * 60);
      expect(session.state.remainingSeconds, 45 * 60);
      expect(session.state.running, isFalse);
    });
  });

  testWidgets('screen re-entry shows deadline-based time after screen disposal', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 15, 12);
    final session = FocusTimerSession(clock: () => now);

    await tester.pumpWidget(
      MaterialApp(home: FocusTimerScreen(session: session)),
    );
    await tester.tap(find.text('Start'));
    await tester.pump();
    expect(find.text('25:00'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    now = now.add(const Duration(minutes: 1));
    await tester.pumpWidget(
      MaterialApp(home: FocusTimerScreen(session: session)),
    );
    await tester.pump();

    expect(find.text('24:00'), findsOneWidget);
    expect(find.text('FOCUSING'), findsOneWidget);
  });

  testWidgets('resume lifecycle syncs the deadline after background time', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 15, 12);
    final session = FocusTimerSession(clock: () => now);

    await tester.pumpWidget(
      MaterialApp(home: FocusTimerScreen(session: session)),
    );
    await tester.tap(find.text('Start'));
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    now = now.add(const Duration(seconds: 70));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.text('23:50'), findsOneWidget);
    expect(session.state.running, isTrue);
  });
}
