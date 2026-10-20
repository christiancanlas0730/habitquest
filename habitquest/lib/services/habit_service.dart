import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/account_date.dart';
import '../models/habit.dart';
import '../models/habit_completion.dart';
import '../models/gamification.dart';
import '../models/completion_date_policy.dart';
import '../models/completion_recovery.dart';
import '../models/virtual_pet.dart';
import '../models/smart_productivity.dart';
import 'habit_repository.dart';

class CompletionSummaryUpdateException implements Exception {
  const CompletionSummaryUpdateException({
    required this.streak,
    required this.completedOn,
  });

  final int? streak;
  final String completedOn;

  String get message =>
      'Habit completion is saved to history, but its streak summary could not sync. Refresh to retry.';
}

class UnauthenticatedHabitServiceException implements Exception {
  const UnauthenticatedHabitServiceException();

  @override
  String toString() => 'User is not authenticated.';
}

class CompletionTimeZoneRequiredException implements Exception {
  const CompletionTimeZoneRequiredException();

  String get message =>
      'Set a valid completion timezone in Profile before completing a habit.';
}

String completionTimeZoneErrorMessage(
  Object error, {
  required String fallback,
}) {
  if (error is PostgrestException && error.code == 'PGRST202') {
    return 'The timezone service is unavailable. Its migration may be missing '
        'or the API schema cache may need refresh. Habit completion remains disabled.';
  }
  return fallback;
}

String completionTimeZoneSaveErrorMessage(
  Object error, {
  required String fallback,
}) {
  if (error is! PostgrestException) {
    return completionTimeZoneErrorMessage(error, fallback: fallback);
  }
  if (error.code == '22023') {
    // The server returns the same SQLSTATE for invalid zones and cooldown.
    // Recognize only that specific policy without rendering raw server text.
    final message = error.message.toLowerCase();
    if (message.contains('once every 30 days')) {
      return 'Timezone changes are limited to once every 30 days.';
    }
    return 'Use a valid IANA timezone.';
  }
  return completionTimeZoneErrorMessage(error, fallback: fallback);
}

/// Checks the identifier shape accepted by the prepared server policy.
/// PostgreSQL remains responsible for validating the IANA database entry.
bool isUsableCompletionTimeZone(String? value) {
  return value != null && AccountDateSource.isValidTimeZone(value);
}

class HabitCompletionResult implements CompletionActionResult {
  const HabitCompletionResult({
    required this.streak,
    required this.reward,
    required this.isVerified,
    required this.completedOn,
  });

  @override
  final int? streak;
  @override
  final bool isVerified;
  @override
  final String completedOn;

  /// Null means the completion was saved but its reward RPC needs a retry.
  @override
  final CompletionReward? reward;

  @override
  String get completedOnString => completedOn;

  @override
  bool get rewardPending => isVerified && reward == null;

  @override
  int get earnedXp => reward?.earnedXp ?? 0;

}

class HabitService
    implements
        HabitCompletionRepository,
        HabitHomeRepository,
        HabitDetailRepository,
        HabitFormRepository,
        HabitBrowserRepository,
        AccountDateRepository,
        ReminderRepository,
        ProfileRepository,
        PetRepository,
        MoodJournalRepository {
  HabitService({SupabaseClient? client})
    : supabase = client ?? Supabase.instance.client;

  @override
  final SupabaseClient supabase;

  @override
  String? get currentUserEmail => supabase.auth.currentUser?.email;

  // Get the currently logged-in user's ID
  String get userId {
    final id = supabase.auth.currentUser?.id;
    if (id == null) throw const UnauthenticatedHabitServiceException();
    return id;
  }

  @override
  Future<String?> getCompletionTimeZone() async {
    return (await getCompletionTimeZoneSettings())?.timeZone;
  }

  @override
  Future<CompletionTimeZoneSettings?> getCompletionTimeZoneSettings() async {
    final result = await supabase.rpc('get_completion_time_zone');
    return CompletionTimeZoneSettings.fromRpc(result);
  }

  @override
  Future<CompletionTimeZoneSettings> setCompletionTimeZone(
    String timeZone,
  ) async {
    final requestedTimeZone = timeZone.trim();
    if (!isUsableCompletionTimeZone(requestedTimeZone)) {
      throw const FormatException(
        'Enter a timezone such as Asia/Singapore or UTC.',
      );
    }
    final result = await supabase.rpc(
      'set_completion_time_zone',
      params: {'p_time_zone': requestedTimeZone},
    );
    final settings = CompletionTimeZoneSettings.fromRpc(result);
    if (settings == null || !isUsableCompletionTimeZone(settings.timeZone)) {
      throw const FormatException(
        'Timezone save returned an invalid timezone.',
      );
    }
    if (settings.timeZone != requestedTimeZone) {
      throw const FormatException(
        'Timezone save did not confirm the requested timezone.',
      );
    }
    return settings;
  }

  Future<bool> hasCompletionTimeZone() async {
    return await getCompletionTimeZoneSettings() != null;
  }

  // Get all habits of the current user
  @override
  Future<List<Habit>> getHabits() async =>
      (await supabase
              .from('habits')
              .select()
              .eq('user_id', userId)
              .order('created_at', ascending: false))
          .map<Habit>((item) => Habit.fromMap(item))
          .toList();

  // Reads history only for habits already fetched for the signed-in user.
  @override
  Future<List<HabitCompletion>> getCompletionHistory(
    Iterable<String> habitIds,
  ) async {
    final ids = habitIds.toSet().toList();
    if (ids.isEmpty) return [];

    final rows = await fetchInclusivePages<Map<String, dynamic>>(
      fetchPage: (from, to) async => (await supabase
              .from('habit_completions')
              .select('habit_id, completed_on')
              .inFilter('habit_id', ids)
              .order('completed_on')
              .order('habit_id')
              .range(from, to))
          .cast<Map<String, dynamic>>(),
    );
    // Pagination terminates based on raw server rows; dedupe only after every
    // page is complete so repeated records cannot shorten or skip a page.
    return deduplicateHabitCompletions(rows.map(HabitCompletion.fromMap));
  }

  @override
  Future<CompletionHistorySnapshot> loadCompletionHistory() async {
    final habits = await getHabits();
    final completions = await getCompletionHistory(
      habits.map((habit) => habit.id),
    );
    return CompletionHistorySnapshot(habits: habits, completions: completions);
  }

  // Add a new habit
  @override
  Future<void> addHabit({
    required String name,
    required String category,
    required String frequency,
  }) async {
    final user = supabase.auth.currentUser;
    final session = supabase.auth.currentSession;
    if (user == null || session == null) {
      throw const UnauthenticatedHabitServiceException();
    }
    await supabase.from('habits').insert({
      'user_id': user.id,
      'name': name,
      'category': category,
      'frequency': frequency,
      'streak': 0,
    });
  }

  // Update a habit
  @override
  Future<Habit> updateHabit({
    required String id,
    required String name,
    required String category,
    required String frequency,
  }) async {
    final data = await supabase
        .from('habits')
        .update({'name': name, 'category': category, 'frequency': frequency})
        .eq('id', id)
        .eq('user_id', userId)
        .select()
        .single();
    return Habit.fromMap(data);
  }

  // Delete a habit
  @override
  Future<void> deleteHabit(String id) async {
    await supabase
        .from('habits')
        .delete()
        .eq('id', id)
        .eq('user_id', userId)
        .select('id')
        .single();
  }

  // Complete a habit for today
  Future<HabitCompletionResult> completeHabit(Habit habit) async {
    try {
      if (!await hasCompletionTimeZone()) {
        throw const CompletionTimeZoneRequiredException();
      }
      // The server chooses the date from transaction time and the stored
      // account timezone. Always call the RPC so stale client dates cannot
      // suppress a retry or influence the completion key.
      final completion = await _recordHabitCompletion(habit.id);
      final completedOn = completion.completedOn;
      final todayString = completion.completedOnString;
      int? newStreak = habit.streak;
      if (completion.inserted) {
        if (habit.frequency == 'Twice a week') {
          try {
            final history = await getCompletionHistory([habit.id]);
            newStreak = habit.streakAfterCompletionWithHistory(
              completedOn,
              completionHistory: history.map(
                (item) => item.calendarDate!.utcDate,
              ),
            );
          } catch (_) {
            newStreak = null;
          }
        } else {
          newStreak = habit.streakAfterCompletionOn(completedOn);
        }
      }

      // A duplicate RPC call is idempotent. The client's habit snapshot may
      // be stale, so never overwrite the server summary from it on a retry.
      if (completion.inserted) {
        try {
          final summary = <String, dynamic>{'last_completed_date': todayString};
          if (newStreak != null) summary['streak'] = newStreak;
          await supabase
              .from('habits')
              .update(summary)
              .eq('id', habit.id)
              .eq('user_id', userId)
              .select('id')
              .single();
        } catch (_) {
          if (completion.isVerified) {
            throw CompletionSummaryUpdateException(
              streak: newStreak,
              completedOn: todayString,
            );
          }
          rethrow;
        }
      }

      // The completion row and streak summary are already committed. A
      // missing or temporarily unavailable rewards RPC must not turn that
      // successful save into a failed completion; recovery retries it later.
      final reward = completion.isVerified
          ? await tryClaimPersistedReward(
              () => _claimRewards(habit.id, todayString),
            )
          : null;
      return HabitCompletionResult(
        streak: newStreak,
        reward: reward,
        isVerified: completion.isVerified,
        completedOn: todayString,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<ServerCompletion> _recordHabitCompletion(String habitId) async {
    try {
      final result = await supabase.rpc(
        'record_habit_completion',
        params: {'p_habit_id': habitId},
      );
      return CompletionDatePolicy.parseServerCompletion(result);
    } on PostgrestException catch (error) {
      if (error.code == 'P0001' &&
          error.message.contains('Completion timezone')) {
        throw const CompletionTimeZoneRequiredException();
      }
      rethrow;
    }
  }

  Future<CompletionReward> _claimRewards(
    String habitId,
    String completedOn,
  ) async {
    final result = await supabase.rpc(
      'claim_completion_rewards',
      params: {'p_habit_id': habitId, 'p_completed_on': completedOn},
    );
    return CompletionReward.fromMap(Map<String, dynamic>.from(result as Map));
  }

  Future<List<Habit>> reconcileCompletionHistory(List<Habit> habits) async {
    if (habits.isEmpty) return habits;

    final completions = await getCompletionHistory(
      habits.map((habit) => habit.id),
    );
    Set<String> rewardKeys;
    try {
      rewardKeys = await _getRecordedCompletionRewardKeys();
    } on PostgrestException catch (error) {
      if (!isMissingOptionalRelationCode(error.code)) rethrow;
      rewardKeys = const {};
    }
    final verifiedKeys = await _getVerifiedCompletionKeys();

    return runCompletionRecovery(
      habits: habits,
      completions: completions,
      recordedRewardKeys: rewardKeys,
      verifiedCompletionKeys: verifiedKeys,
      persistSummary: (habit) async {
        try {
          await supabase
              .from('habits')
              .update({
                'streak': habit.streak,
                'last_completed_date': habit.lastCompletedDate,
              })
              .eq('id', habit.id)
              .eq('user_id', userId)
              .select('id')
              .single();
        } catch (_) {
          // Keep the screen available. The stale summary will be retried on
          // the next refresh, based again on the persisted completion history.
        }
      },
      claimReward: (completion) async {
        try {
          await _claimRewards(completion.habitId, completion.completedOn);
        } catch (_) {
          // The absent ledger key makes the reward eligible for a safe retry.
        }
      },
    );
  }

  Future<Set<String>> _getVerifiedCompletionKeys() async {
    try {
      final rows = await supabase.rpc('get_verified_completion_keys');
      return (rows as List).map((row) {
        final value = Map<String, dynamic>.from(row as Map);
        return '${value['habit_id']}:${value['completed_on']}';
      }).toSet();
    } on PostgrestException catch (error) {
      if (!isMissingOptionalRelationCode(error.code) &&
          error.code != 'PGRST202' &&
          error.code != '42883') {
        rethrow;
      }
      // Without the server verification list, recovery must not request
      // rewards for historical rows whose provenance is unknown.
      return const {};
    }
  }

  Future<Set<String>> _getRecordedCompletionRewardKeys() async {
    const pageSize = 500;
    final keys = <String>{};
    var offset = 0;
    try {
      while (true) {
        final page = await supabase
            .from('xp_ledger')
            .select('idempotency_key')
            .eq('user_id', userId)
            .like('idempotency_key', 'completion:%')
            .order('id')
            .range(offset, offset + pageSize - 1);
        keys.addAll(page.map((row) => row['idempotency_key'].toString()));
        if (page.length < pageSize) break;
        offset += pageSize;
      }
    } on PostgrestException catch (error) {
      if (!isMissingOptionalRelationCode(error.code)) rethrow;
      // With no ledger, recovery tries the idempotent reward RPC. It may also
      // be absent, in which case the next refresh will retry again.
    }
    return keys;
  }

  @override
  Future<GamificationProgress> getGamificationProgress({
    required Iterable<String> habitIds,
    DateTime? localDate,
  }) async {
    final xpRows = await supabase
        .from('xp_ledger')
        .select('amount')
        .eq('user_id', userId);
    final achievementRows = await supabase
        .from('user_achievements')
        .select('achievement_key')
        .eq('user_id', userId);
    int? completedToday;
    if (localDate != null) {
      final today = _dateString(localDate);
      final completions = await getCompletionHistory(habitIds);
      completedToday = completions
          .where((completion) => completion.completedOn == today)
          .length;
    }
    return GamificationProgress.fromRows(
      xpRows: xpRows.cast<Map<String, dynamic>>(),
      achievementRows: achievementRows.cast<Map<String, dynamic>>(),
      completedToday: completedToday,
    );
  }

  @override
  Future<VirtualPetSnapshot> getVirtualPetSnapshot() async {
    var growth = PetGrowth.fromVerifiedCount(null);
    try {
      final verifiedCount = await supabase.rpc('get_verified_completion_count');
      growth = PetGrowth.fromVerifiedCount(verifiedCount);
    } on PostgrestException catch (error) {
      if (!isMissingOptionalRoutineCode(error.code)) rethrow;
      // Without the verification RPC, legacy completion history must not
      // unlock pet growth or cosmetics.
    }

    var preferences = const PetPreferences();
    var cloudPersistenceAvailable = true;
    try {
      final row = await supabase
          .from('pet_preferences')
          .select('pet_name, equipped_item_key')
          .eq('user_id', userId)
          .maybeSingle();
      preferences = PetPreferences.fromMap(row);
    } on PostgrestException catch (error) {
      if (!isMissingOptionalRelationCode(error.code)) rethrow;
      cloudPersistenceAvailable = false;
    }

    return VirtualPetSnapshot(
      growth: growth,
      preferences: preferences,
      cloudPersistenceAvailable: cloudPersistenceAvailable,
    );
  }

  /// Returns false only when the review-only pet migration is not installed.
  @override
  Future<bool> savePetPreferences(PetPreferences preferences) async {
    try {
      await supabase.rpc(
        'save_pet_preferences',
        params: {
          'p_pet_name': preferences.name,
          'p_equipped_item_key': preferences.equippedItemKey,
        },
      );
      return true;
    } on PostgrestException catch (error) {
      if (!isMissingOptionalRoutineCode(error.code)) rethrow;
      return false;
    }
  }

  Future<HabitRemindersSnapshot> getHabitReminders() async {
    try {
      final rows = await supabase
          .from('habit_reminders')
          .select('habit_id, enabled, reminder_time')
          .eq('user_id', userId);
      final preferences = <String, HabitReminderPreference>{
        for (final row in rows)
          row['habit_id'].toString(): HabitReminderPreference.fromMap(
            Map<String, dynamic>.from(row),
          ),
      };
      return HabitRemindersSnapshot(
        preferences: preferences,
        cloudPersistenceAvailable: true,
      );
    } on PostgrestException catch (error) {
      if (!isMissingOptionalRelationCode(error.code)) rethrow;
      return const HabitRemindersSnapshot(
        preferences: {},
        cloudPersistenceAvailable: false,
      );
    }
  }

  @override
  Future<bool> saveHabitReminder(HabitReminderPreference preference) async {
    try {
      await supabase
          .from('habit_reminders')
          .upsert(preference.toMap(userId), onConflict: 'user_id,habit_id');
      return true;
    } on PostgrestException catch (error) {
      if (!isMissingOptionalRelationCode(error.code)) rethrow;
      return false;
    }
  }

  @override
  Future<MoodJournalSnapshot> getMoodEntry(DateTime localDate) async {
    try {
      final row = await supabase
          .from('mood_entries')
          .select('entry_date, mood, note')
          .eq('user_id', userId)
          .eq('entry_date', _dateString(localDate))
          .maybeSingle();
      return MoodJournalSnapshot(
        entry: row == null ? null : MoodEntry.fromMap(row),
        cloudPersistenceAvailable: true,
      );
    } on PostgrestException catch (error) {
      if (!isMissingOptionalRelationCode(error.code)) rethrow;
      return const MoodJournalSnapshot(
        entry: null,
        cloudPersistenceAvailable: false,
      );
    }
  }

  @override
  Future<bool> saveMoodEntry(MoodEntry entry) async {
    try {
      await supabase
          .from('mood_entries')
          .upsert(entry.toMap(userId), onConflict: 'user_id,entry_date');
      return true;
    } on PostgrestException catch (error) {
      if (error.code != 'PGRST205' && error.code != '42P01') rethrow;
      return false;
    }
  }

  String _dateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
