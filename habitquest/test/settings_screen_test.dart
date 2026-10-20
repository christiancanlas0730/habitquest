import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit__quest/models/account_date.dart';
import 'package:habit__quest/screens/settings_screen.dart';
import 'package:habit__quest/services/habit_repository.dart';

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository({this.timeZone = 'UTC'});

  String? timeZone;
  bool failLoad = false;
  bool failSave = false;
  String? lastSavedTimeZone;

  CompletionTimeZoneSettings? _settings() => timeZone == null
      ? null
      : CompletionTimeZoneSettings(
          timeZone: timeZone!,
          updatedAt: DateTime.utc(2026, 10, 1),
          nextChangeAt: DateTime.utc(2026, 10, 31),
        );

  @override
  Future<String?> getCompletionTimeZone() async => timeZone;

  @override
  Future<CompletionTimeZoneSettings?> getCompletionTimeZoneSettings() async {
    if (failLoad) throw StateError('load failed');
    return _settings();
  }

  @override
  Future<CompletionTimeZoneSettings> setCompletionTimeZone(
    String value,
  ) async {
    if (failSave) throw StateError('save failed');
    lastSavedTimeZone = value;
    timeZone = value;
    return _settings()!;
  }
}

Future<void> _pumpSettings(
  WidgetTester tester,
  _FakeProfileRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(home: SettingsScreen(repository: repository)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('loads and saves the existing account timezone setting', (
    tester,
  ) async {
    final repository = _FakeProfileRepository();
    await _pumpSettings(tester, repository);

    expect(find.text('Settings'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'UTC',
    );
    await tester.enterText(find.byType(TextField), 'Asia/Singapore');
    await tester.tap(find.text('Save timezone'));
    await tester.pumpAndSettle();

    expect(repository.lastSavedTimeZone, 'Asia/Singapore');
    expect(find.text('Completion timezone saved.'), findsOneWidget);
  });

  testWidgets('shows timezone policy timestamp as account-local date', (
    tester,
  ) async {
    final repository = _FakeProfileRepository(timeZone: 'America/Los_Angeles');
    await _pumpSettings(tester, repository);

    expect(
      find.text('Next change available after 2026-10-30.'),
      findsOneWidget,
    );
  });

  testWidgets('rejects malformed timezone input without saving', (
    tester,
  ) async {
    final repository = _FakeProfileRepository();
    await _pumpSettings(tester, repository);

    await tester.enterText(find.byType(TextField), 'not a timezone');
    await tester.tap(find.text('Save timezone'));
    await tester.pump();

    expect(find.text('Enter a valid IANA timezone, such as UTC.'), findsOneWidget);
    expect(repository.lastSavedTimeZone, isNull);
  });

  testWidgets('shows save failure and retains the entered value', (
    tester,
  ) async {
    final repository = _FakeProfileRepository()..failSave = true;
    await _pumpSettings(tester, repository);

    await tester.enterText(find.byType(TextField), 'Asia/Tokyo');
    await tester.tap(find.text('Save timezone'));
    await tester.pumpAndSettle();

    expect(
      find.text('Timezone could not be saved. Check your connection and try again.'),
      findsOneWidget,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Asia/Tokyo',
    );
  });
}
