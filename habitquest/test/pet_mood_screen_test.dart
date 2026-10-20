import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit__quest/models/habit.dart';
import 'package:habit__quest/models/habit_reminder_save.dart';
import 'package:habit__quest/models/smart_productivity.dart';
import 'package:habit__quest/models/virtual_pet.dart';
import 'package:habit__quest/screens/habit_reminders_screen.dart';
import 'package:habit__quest/screens/mood_journal_screen.dart';
import 'package:habit__quest/screens/virtual_pet_screen.dart';
import 'package:habit__quest/services/habit_repository.dart';

class _PetRepository implements PetRepository {
  _PetRepository({this.saveError, this.saveCompleter});

  final Object? saveError;
  final Completer<bool>? saveCompleter;
  PetPreferences savedPreferences = const PetPreferences();
  int saveCalls = 0;

  @override
  Future<VirtualPetSnapshot> getVirtualPetSnapshot() async =>
      VirtualPetSnapshot(
        growth: const PetGrowth(completionCount: 0),
        preferences: savedPreferences,
        cloudPersistenceAvailable: true,
      );

  @override
  Future<bool> savePetPreferences(PetPreferences preferences) async {
    saveCalls++;
    if (saveError != null) throw saveError!;
    final saved = await (saveCompleter?.future ?? Future.value(true));
    if (saved) savedPreferences = preferences;
    return saved;
  }
}

class _MoodRepository implements MoodJournalRepository {
  _MoodRepository({this.saveResult = true});

  final bool saveResult;
  MoodJournalSnapshot snapshot = const MoodJournalSnapshot(
    entry: null,
    cloudPersistenceAvailable: true,
  );
  MoodEntry? savedEntry;
  int saveCalls = 0;

  @override
  Future<MoodJournalSnapshot> getMoodEntry(DateTime localDate) async =>
      snapshot;

  @override
  Future<bool> saveMoodEntry(MoodEntry entry) async {
    saveCalls++;
    savedEntry = entry;
    return saveResult;
  }
}

class _ReminderRepository implements ReminderRepository {
  _ReminderRepository({this.saveCompleter, this.saveError});

  final Completer<bool>? saveCompleter;
  final Object? saveError;
  int saveCalls = 0;
  HabitReminderPreference? attemptedPreference;

  @override
  Future<List<Habit>> getHabits() async => [
    Habit(
      id: 'habit-1',
      userId: 'user-1',
      name: 'Read',
      category: 'Study',
      frequency: 'Every day',
      streak: 0,
    ),
  ];

  @override
  Future<HabitRemindersSnapshot> getHabitReminders() async =>
      const HabitRemindersSnapshot(
        preferences: {
          'habit-1': HabitReminderPreference(
            habitId: 'habit-1',
            enabled: false,
            time: '09:00',
          ),
        },
        cloudPersistenceAvailable: true,
      );

  @override
  Future<bool> saveHabitReminder(HabitReminderPreference preference) async {
    saveCalls++;
    attemptedPreference = preference;
    if (saveError != null) throw saveError!;
    return saveCompleter?.future ?? Future.value(false);
  }
}

void main() {
  testWidgets('pet rename uses the injected repository', (tester) async {
    final repository = _PetRepository();
    await tester.pumpWidget(
      MaterialApp(home: VirtualPetScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Rename pet'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Pip');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.saveCalls, 1);
    expect(repository.savedPreferences.name, 'Pip');
    expect(find.text('Pip'), findsWidgets);
  });

  testWidgets('pet save failure keeps the existing name', (tester) async {
    final repository = _PetRepository(saveError: StateError('offline'));
    await tester.pumpWidget(
      MaterialApp(home: VirtualPetScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Rename pet'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Pip');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.saveCalls, 1);
    expect(repository.savedPreferences.name, 'Mochi');
    expect(find.text('Mochi'), findsWidgets);
    expect(find.text('Pip'), findsNothing);
    expect(
      tester.widget<IconButton>(find.byTooltip('Rename pet')).onPressed,
      isNotNull,
    );
  });

  testWidgets('pet save failure after disposal does not use stale context', (
    tester,
  ) async {
    final saveCompleter = Completer<bool>();
    final repository = _PetRepository(saveCompleter: saveCompleter);
    await tester.pumpWidget(
      MaterialApp(home: VirtualPetScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Rename pet'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Pip');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(repository.saveCalls, 1);
    expect(
      tester.widget<IconButton>(find.byTooltip('Rename pet')).onPressed,
      isNull,
    );

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    saveCompleter.completeError(StateError('offline'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('mood check-in saves a trimmed note through its repository', (
    tester,
  ) async {
    final repository = _MoodRepository();
    await tester.pumpWidget(
      MaterialApp(home: MoodJournalScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Good'));
    await tester.enterText(find.byType(TextField), '  A calm day.  ');
    await tester.ensureVisible(find.text('Save check-in'));
    await tester.tap(find.text('Save check-in'));
    await tester.pumpAndSettle();

    expect(repository.saveCalls, 1);
    expect(repository.savedEntry?.mood, 'good');
    expect(repository.savedEntry?.note, 'A calm day.');
    expect(repository.savedEntry?.entryDate, matches(r'^\d{4}-\d{2}-\d{2}$'));
    expect(
      find.text('Today’s mood entry is saved privately to your account.'),
      findsOneWidget,
    );
  });

  testWidgets('mood save is blocked until a mood is selected', (tester) async {
    final repository = _MoodRepository();
    await tester.pumpWidget(
      MaterialApp(home: MoodJournalScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save check-in'));
    await tester.tap(find.text('Save check-in'));
    await tester.pumpAndSettle();

    expect(repository.saveCalls, 0);
    expect(find.text('Choose a mood before saving.'), findsOneWidget);
  });

  testWidgets('unavailable mood persistence does not claim the entry saved', (
    tester,
  ) async {
    final repository = _MoodRepository(saveResult: false);
    await tester.pumpWidget(
      MaterialApp(home: MoodJournalScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Good'));
    await tester.ensureVisible(find.text('Save check-in'));
    await tester.tap(find.text('Save check-in'));
    await tester.pumpAndSettle();

    expect(repository.saveCalls, 1);
    expect(
      find.text(
        'Mood sync is unavailable until the journal migration is applied. '
        'This entry was not saved.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Today’s mood entry is saved privately to your account.'),
      findsNothing,
    );
  });

  testWidgets('failed reminder persistence keeps the saved switch state', (
    tester,
  ) async {
    final saveCompleter = Completer<bool>();
    final repository = _ReminderRepository(saveCompleter: saveCompleter);
    await tester.pumpWidget(
      MaterialApp(home: HabitRemindersScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(repository.saveCalls, 1);
    expect(repository.attemptedPreference?.enabled, isTrue);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNull,
    );

    saveCompleter.complete(false);
    await tester.pumpAndSettle();

    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    expect(
      find.text(
        'Preference is temporary until the reminders migration is applied.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('reminder save exception re-enables the control for retry', (
    tester,
  ) async {
    final repository = _ReminderRepository(saveError: StateError('offline'));
    await tester.pumpWidget(
      MaterialApp(home: HabitRemindersScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(repository.saveCalls, 1);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNotNull,
    );
    expect(
      find.text('Could not save this reminder preference.'),
      findsOneWidget,
    );
  });
}
