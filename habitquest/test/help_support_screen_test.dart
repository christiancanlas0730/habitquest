import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit__quest/screens/help_support_screen.dart';

void main() {
  testWidgets('search filters FAQs and clear restores all topics', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HelpSupportScreen()),
    );

    expect(find.text('How do I create or change a habit?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'notification');
    await tester.pump();

    expect(find.text('Why did a habit reminder not notify me?'), findsOneWidget);
    expect(find.text('How do I use the focus timer?'), findsNothing);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();

    expect(find.text('How do I create or change a habit?'), findsOneWidget);
  });

  testWidgets('category filter narrows topics and empty query is explained', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HelpSupportScreen()),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'Focus'));
    await tester.pump();
    expect(find.text('How do I use the focus timer?'), findsOneWidget);
    expect(find.text('How do I sign out?'), findsNothing);

    await tester.enterText(find.byType(TextField), 'not a topic');
    await tester.pump();
    expect(find.text('No help topics match your search.'), findsOneWidget);
  });

  testWidgets('reminder answer does not promise notification delivery', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HelpSupportScreen()),
    );

    await tester.enterText(find.byType(TextField), 'reminder not notify');
    await tester.pump();
    await tester.tap(find.text('Why did a habit reminder not notify me?'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('does not schedule operating-system or browser notifications'),
      findsOneWidget,
    );
  });
}
