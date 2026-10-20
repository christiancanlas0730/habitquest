import 'habit.dart';
import 'habit_completion.dart';

/// Missing optional relations and absent RPCs may degrade only where the
/// caller explicitly supports an unapplied optional migration.
bool isMissingOptionalRelationCode(String? code) =>
    code == 'PGRST205' || code == '42P01';

bool isMissingOptionalRoutineCode(String? code) =>
    code == 'PGRST202' || code == '42883';

/// A reward attempt can fail after a completion has already been persisted.
/// Returning null keeps that completion successful while allowing refresh to
/// retry the idempotent server claim.
Future<T?> tryClaimPersistedReward<T>(Future<T> Function() claim) async {
  try {
    return await claim();
  } catch (_) {
    return null;
  }
}

String completionRewardKey(HabitCompletion completion) =>
    'completion:${completion.habitId}:${completion.completedOn}';

class CompletionRecoveryPlan {
  const CompletionRecoveryPlan({
    required this.habits,
    required this.summariesToPersist,
    required this.rewardsToClaim,
  });

  final List<Habit> habits;
  final List<Habit> summariesToPersist;
  final List<HabitCompletion> rewardsToClaim;
}

CompletionRecoveryPlan planCompletionRecovery({
  required List<Habit> habits,
  required List<HabitCompletion> completions,
  required Set<String> recordedRewardKeys,
  required Set<String> verifiedCompletionKeys,
}) {
  final repaired = {for (final habit in habits) habit.id: habit};
  final changedIds = <String>{};
  final uniqueCompletions = <String, HabitCompletion>{};

  for (final completion in completions) {
    if (completion.calendarDate == null) continue;
    uniqueCompletions.putIfAbsent(
      '${completion.habitId}:${completion.completedOn}',
      () => completion,
    );
  }

  final orderedCompletions = uniqueCompletions.values.toList()
    ..sort((a, b) {
      final dateOrder = a.completedOn.compareTo(b.completedOn);
      return dateOrder != 0 ? dateOrder : a.habitId.compareTo(b.habitId);
    });

  for (final completion in orderedCompletions) {
    final habit = repaired[completion.habitId];
    if (habit == null) continue;
    final lastDate = habit.lastCompletedDate;
    if (lastDate != null && completion.completedOn.compareTo(lastDate) <= 0) {
      continue;
    }

    final date = completion.calendarDate!.utcDate;
    final nextHabit = Habit(
      id: habit.id,
      userId: habit.userId,
      name: habit.name,
      category: habit.category,
      frequency: habit.frequency,
      streak: habit.frequency == 'Twice a week'
          ? habit.streakAfterCompletionWithHistory(
              date,
              completionHistory: orderedCompletions
                  .where((item) => item.habitId == habit.id)
                  .map((item) => item.calendarDate!.utcDate),
            )
          : habit.streakAfterCompletionOn(date),
      lastCompletedDate: completion.completedOn,
      createdAt: habit.createdAt,
    );
    repaired[habit.id] = nextHabit;
    changedIds.add(habit.id);
  }

  return CompletionRecoveryPlan(
    habits: habits.map((habit) => repaired[habit.id]!).toList(),
    summariesToPersist: [
      for (final habit in habits)
        if (changedIds.contains(habit.id)) repaired[habit.id]!,
    ],
    rewardsToClaim: [
      for (final completion in orderedCompletions)
        if (repaired.containsKey(completion.habitId) &&
            verifiedCompletionKeys.contains(
              '${completion.habitId}:${completion.completedOn}',
            ) &&
            !recordedRewardKeys.contains(completionRewardKey(completion)))
          completion,
    ],
  );
}

Future<List<Habit>> runCompletionRecovery({
  required List<Habit> habits,
  required List<HabitCompletion> completions,
  required Set<String> recordedRewardKeys,
  required Set<String> verifiedCompletionKeys,
  required Future<void> Function(Habit habit) persistSummary,
  required Future<void> Function(HabitCompletion completion) claimReward,
}) async {
  final plan = planCompletionRecovery(
    habits: habits,
    completions: completions,
    recordedRewardKeys: recordedRewardKeys,
    verifiedCompletionKeys: verifiedCompletionKeys,
  );

  for (final habit in plan.summariesToPersist) {
    await persistSummary(habit);
  }
  for (final completion in plan.rewardsToClaim) {
    await claimReward(completion);
  }
  return plan.habits;
}
