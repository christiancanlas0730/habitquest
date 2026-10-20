import 'package:flutter/material.dart';
import '../models/gamification.dart';
import '../widgets/premium_ui.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key, required this.progress});

  final GamificationProgress progress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Achievements')),
      body: PremiumBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              GlassCard(
                glow: true,
                child: Row(
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: AppColors.orange,
                      size: 34,
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${progress.unlockedKeys.length} unlocked',
                            style: const TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Keep showing up to earn more.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionHeading(title: 'Milestones'),
              const SizedBox(height: 12),
              for (final achievement in AchievementDefinition.all) ...[
                _AchievementCard(
                  definition: achievement,
                  unlocked: progress.unlockedKeys.contains(achievement.key),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.definition, required this.unlocked});

  final AchievementDefinition definition;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: unlocked ? const Color(0xCC1B202A) : const Color(0x99131820),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: unlocked
              ? AppColors.orange.withValues(alpha: 0.34)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (unlocked ? AppColors.orange : AppColors.faint).withValues(
                alpha: 0.14,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              unlocked ? definition.icon : '🔒',
              style: const TextStyle(fontSize: 23),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  definition.title,
                  style: TextStyle(
                    color: unlocked ? AppColors.text : AppColors.muted,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  definition.description,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            unlocked ? 'Earned' : '+${definition.rewardXp} XP',
            style: TextStyle(
              color: unlocked ? AppColors.green : AppColors.blue,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
