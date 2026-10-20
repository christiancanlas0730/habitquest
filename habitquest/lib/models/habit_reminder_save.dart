import 'smart_productivity.dart';

class HabitReminderSaveResult {
  const HabitReminderSaveResult({
    required this.preferences,
    required this.cloudPersistenceAvailable,
    required this.saved,
  });

  final Map<String, HabitReminderPreference> preferences;
  final bool cloudPersistenceAvailable;
  final bool saved;

  factory HabitReminderSaveResult.apply({
    required Map<String, HabitReminderPreference> current,
    required HabitReminderPreference preference,
    required bool cloudPersistenceAvailable,
    required bool persisted,
  }) {
    final next = Map<String, HabitReminderPreference>.from(current);
    if (!cloudPersistenceAvailable || persisted) {
      next[preference.habitId] = preference;
    }
    return HabitReminderSaveResult(
      preferences: Map.unmodifiable(next),
      cloudPersistenceAvailable: cloudPersistenceAvailable && persisted,
      saved: persisted,
    );
  }
}
