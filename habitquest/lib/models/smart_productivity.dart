class HabitReminderPreference {
  const HabitReminderPreference({
    required this.habitId,
    required this.enabled,
    required this.time,
  });

  final String habitId;
  final bool enabled;
  final String time;

  factory HabitReminderPreference.fromMap(Map<String, dynamic> row) =>
      HabitReminderPreference(
        habitId: row['habit_id'].toString(),
        enabled: row['enabled'] == true,
        time: row['reminder_time']?.toString().substring(0, 5) ?? '09:00',
      );

  Map<String, dynamic> toMap(String userId) => {
    'user_id': userId,
    'habit_id': habitId,
    'enabled': enabled,
    'reminder_time': time,
  };

  HabitReminderPreference copyWith({bool? enabled, String? time}) =>
      HabitReminderPreference(
        habitId: habitId,
        enabled: enabled ?? this.enabled,
        time: time ?? this.time,
      );
}

class HabitRemindersSnapshot {
  const HabitRemindersSnapshot({
    required this.preferences,
    required this.cloudPersistenceAvailable,
  });

  final Map<String, HabitReminderPreference> preferences;
  final bool cloudPersistenceAvailable;
}

class MoodEntry {
  const MoodEntry({
    required this.entryDate,
    required this.mood,
    required this.note,
  });

  final String entryDate;
  final String mood;
  final String note;

  factory MoodEntry.fromMap(Map<String, dynamic> row) => MoodEntry(
    entryDate: row['entry_date'].toString(),
    mood: row['mood'].toString(),
    note: row['note']?.toString() ?? '',
  );

  Map<String, dynamic> toMap(String userId) => {
    'user_id': userId,
    'entry_date': entryDate,
    'mood': mood,
    'note': note.trim(),
  };
}

class MoodJournalSnapshot {
  const MoodJournalSnapshot({
    required this.entry,
    required this.cloudPersistenceAvailable,
  });

  final MoodEntry? entry;
  final bool cloudPersistenceAvailable;
}
