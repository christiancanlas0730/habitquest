import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('HabitQuest app loads', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Text('HabitQuest'),
      ),
    );

    expect(find.text('HabitQuest'), findsOneWidget);
  });
}