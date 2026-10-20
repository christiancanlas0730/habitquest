import 'package:flutter/material.dart';
import '../models/habit.dart';
import 'premium_ui.dart';

class HabitCard extends StatelessWidget {
  const HabitCard({
    super.key,
    required this.habit,
    this.onTap,
    this.onComplete,
    this.isCompleted,
    this.showStreakRing = false,
  });

  final Habit habit;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  final bool? isCompleted;
  final bool showStreakRing;

  @override
  Widget build(BuildContext context) {
    final completed = isCompleted ?? habit.lastCompletedDate != null;
    final accent = habitCategoryColor(habit.category);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: completed
              ? const [Color(0xDA1B2832), Color(0xD9131B23)]
              : const [Color(0xD91A202A), Color(0xCB11151D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: completed
              ? AppColors.green.withValues(alpha: 0.32)
              : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: completed
                ? AppColors.green.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.18),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(19),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: accent.withValues(alpha: 0.20)),
                  ),
                  child: Icon(habitCategoryIcon(habit.category),
                      color: accent, size: 24),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: completed ? AppColors.muted : AppColors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          decoration:
                              completed ? TextDecoration.lineThrough : null,
                          decorationColor: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        habit.frequency +
                            (habit.streak > 0
                                ? '  ·  ${habit.streak} day streak'
                                : ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (onComplete != null)
                  _CompletionButton(completed: completed, onPressed: onComplete)
                else if (showStreakRing)
                  _StreakRing(streak: habit.streak, color: accent)
                else
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.faint, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompletionButton extends StatelessWidget {
  const _CompletionButton({required this.completed, required this.onPressed});

  final bool completed;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: completed ? 'Completed today' : 'Complete habit',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: completed ? null : onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: completed
                ? const LinearGradient(
                    colors: [AppColors.green, Color(0xFF36B894)])
                : null,
            color: completed ? null : const Color(0x331A2530),
            border: Border.all(
              color: completed
                  ? AppColors.green
                  : AppColors.faint.withValues(alpha: 0.55),
            ),
          ),
          child: Icon(
            Icons.check_rounded,
            color: completed ? const Color(0xFF07140F) : AppColors.faint,
            size: 21,
          ),
        ),
      ),
    );
  }
}

class _StreakRing extends StatelessWidget {
  const _StreakRing({required this.streak, required this.color});

  final int streak;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 45,
      height: 45,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: streak > 0 ? 1 : 0,
              strokeWidth: 3.5,
              strokeCap: StrokeCap.round,
              backgroundColor: const Color(0xFF343B47),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$streak',
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 1)),
              const SizedBox(height: 2),
              const Text('days',
                  style: TextStyle(
                      color: AppColors.muted, fontSize: 8, height: 1)),
            ],
          ),
        ],
      ),
    );
  }
}
