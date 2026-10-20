class GamificationProgress {
  const GamificationProgress({
    required this.totalXp,
    required this.unlockedKeys,
    required this.completedToday,
  });

  final int totalXp;
  final Set<String> unlockedKeys;
  /// Null when no reliable account-local date is available.
  final int? completedToday;

  int get level => totalXp ~/ 100 + 1;
  int get xpIntoLevel => totalXp % 100;
  double get levelProgress => xpIntoLevel / 100;
  int get xpToNextLevel => 100 - xpIntoLevel;

  factory GamificationProgress.fromRows({
    required Iterable<Map<String, dynamic>> xpRows,
    required Iterable<Map<String, dynamic>> achievementRows,
    required int? completedToday,
  }) {
    final totalXp = xpRows.fold<int>(
      0,
      (sum, row) => sum + ((row['amount'] as num?)?.toInt() ?? 0),
    );
    return GamificationProgress(
      totalXp: totalXp,
      unlockedKeys: achievementRows
          .map((row) => row['achievement_key'].toString())
          .toSet(),
      completedToday: completedToday,
    );
  }
}

class CompletionReward {
  const CompletionReward({
    required this.earnedXp,
    required this.totalXp,
    required this.dailyCompleted,
    required this.unlockedKeys,
  });

  final int earnedXp;
  final int totalXp;
  final int dailyCompleted;
  final List<String> unlockedKeys;

  factory CompletionReward.fromMap(Map<String, dynamic> map) =>
      CompletionReward(
        earnedXp: (map['earned_xp'] as num?)?.toInt() ?? 0,
        totalXp: (map['total_xp'] as num?)?.toInt() ?? 0,
        dailyCompleted: (map['daily_completed'] as num?)?.toInt() ?? 0,
        unlockedKeys: (map['unlocked'] as List<dynamic>? ?? const [])
            .map((value) => value.toString())
            .toList(),
      );
}

class AchievementDefinition {
  const AchievementDefinition({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.rewardXp,
  });

  final String key;
  final String title;
  final String description;
  final String icon;
  final int rewardXp;

  static const all = [
    AchievementDefinition(
      key: 'first_completion',
      title: 'First Step',
      description: 'Complete your first habit.',
      icon: '🌱',
      rewardXp: 20,
    ),
    AchievementDefinition(
      key: 'streak_7',
      title: 'Week of Wins',
      description: 'Reach a seven day habit streak.',
      icon: '🔥',
      rewardXp: 50,
    ),
    AchievementDefinition(
      key: 'completion_25',
      title: 'Momentum',
      description: 'Record 25 habit completions.',
      icon: '🏅',
      rewardXp: 75,
    ),
  ];
}

class DailyQuestDefinition {
  const DailyQuestDefinition({
    required this.key,
    required this.title,
    required this.target,
    required this.rewardXp,
  });

  final String key;
  final String title;
  final int target;
  final int rewardXp;

  static const all = [
    DailyQuestDefinition(
      key: 'one',
      title: 'Start your day',
      target: 1,
      rewardXp: 5,
    ),
    DailyQuestDefinition(
      key: 'three',
      title: 'Build momentum',
      target: 3,
      rewardXp: 15,
    ),
  ];
}
