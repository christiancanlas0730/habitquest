import '../models/habit.dart';
import '../models/habit_completion.dart';
import '../models/account_date.dart';
import '../models/smart_productivity.dart';
import '../models/gamification.dart';
import '../models/virtual_pet.dart';

abstract interface class ReminderRepository {
  Future<List<Habit>> getHabits();
  Future<HabitRemindersSnapshot> getHabitReminders();
  Future<bool> saveHabitReminder(HabitReminderPreference preference);
}

abstract interface class ProfileRepository implements AccountDateRepository {
  Future<String?> getCompletionTimeZone();
  Future<CompletionTimeZoneSettings?> getCompletionTimeZoneSettings();
  Future<CompletionTimeZoneSettings> setCompletionTimeZone(String timeZone);
}

abstract interface class AccountDateRepository {
  Future<CompletionTimeZoneSettings?> getCompletionTimeZoneSettings();
}

abstract interface class PetRepository {
  Future<VirtualPetSnapshot> getVirtualPetSnapshot();
  Future<bool> savePetPreferences(PetPreferences preferences);
}

abstract interface class MoodJournalRepository {
  Future<MoodJournalSnapshot> getMoodEntry(DateTime localDate);
  Future<bool> saveMoodEntry(MoodEntry entry);
}

abstract interface class HabitFormRepository {
  Future<void> addHabit({
    required String name,
    required String category,
    required String frequency,
  });
  Future<Habit> updateHabit({
    required String id,
    required String name,
    required String category,
    required String frequency,
  });
  Future<void> deleteHabit(String id);
}

abstract interface class HabitBrowserRepository implements HabitRepository {
  Future<CompletionHistorySnapshot> loadCompletionHistory();
}

class CompletionHistorySnapshot {
  const CompletionHistorySnapshot({
    required this.habits,
    required this.completions,
  });

  final List<Habit> habits;
  final List<HabitCompletion> completions;
}

/// Persistence seam for habit reads and CRUD. Implementations must apply the
/// same authenticated-user ownership boundary as the Supabase RLS policies.
abstract interface class HabitRepository implements HabitFormRepository {
  Future<List<Habit>> getHabits();
  Future<List<HabitCompletion>> getCompletionHistory(Iterable<String> habitIds);
}

abstract interface class HabitDetailRepository implements HabitRepository {
  Future<bool> hasCompletionTimeZone();
  Future<CompletionTimeZoneSettings?> getCompletionTimeZoneSettings();
  Future<CompletionActionResult> completeHabit(Habit habit);
}

abstract interface class HabitCompletionRepository implements HabitRepository {
  Future<bool> hasCompletionTimeZone();
  Future<CompletionActionResult> completeHabit(Habit habit);
  Future<List<Habit>> reconcileCompletionHistory(List<Habit> habits);
  /// Pass null when the account-local date cannot be resolved. Implementations
  /// must then leave [GamificationProgress.completedToday] unavailable.
  Future<GamificationProgress> getGamificationProgress({
    required Iterable<String> habitIds,
    DateTime? localDate,
  });
  Future<String?> getCompletionTimeZone();
  Future<CompletionTimeZoneSettings> setCompletionTimeZone(String timeZone);
  String? get currentUserEmail;
}

abstract interface class HabitHomeRepository
    implements HabitCompletionRepository, AccountDateRepository {
  String? get currentUserEmail;
}

class CompletionActionResult {
  const CompletionActionResult({
    required this.streak,
    required this.rewardPending,
    required this.earnedXp,
    required this.isVerified,
    required this.completedOn,
    this.reward,
  });

  final int? streak;
  final bool rewardPending;
  final int earnedXp;
  final bool isVerified;
  final String completedOn;
  final CompletionReward? reward;
  String get completedOnString => completedOn;
}
