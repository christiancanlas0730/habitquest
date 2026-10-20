import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../models/habit_completion.dart';
import '../services/habit_repository.dart';
import '../services/habit_service.dart';
import '../widgets/premium_ui.dart';

/// Read-only overview of the user's persisted habits as habit-based goals.
///
/// HabitQuest has no separate goal persistence contract yet, so this screen
/// does not create goal targets or present completion counts as percentages.
class MyGoalsScreen extends StatefulWidget {
  const MyGoalsScreen({super.key, this.repository});

  final HabitRepository? repository;

  @override
  State<MyGoalsScreen> createState() => _MyGoalsScreenState();
}

class _MyGoalsScreenState extends State<MyGoalsScreen> {
  late final HabitRepository _repository = widget.repository ?? HabitService();
  List<Habit> _habits = const [];
  Map<String, int> _completionCounts = const {};
  bool _isLoading = true;
  bool _historyAvailable = true;
  String? _loadError;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    final generation = ++_loadGeneration;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final habits = await _repository.getHabits();
      if (!mounted || generation != _loadGeneration) return;

      Map<String, int> counts = const {};
      var historyAvailable = true;
      if (habits.isNotEmpty) {
        try {
          final history = await _repository.getCompletionHistory(
            habits.map((habit) => habit.id),
          );
          final distinctHistory = deduplicateHabitCompletions(history);
          counts = {
            for (final habit in habits)
              habit.id: distinctHistory
                  .where((completion) => completion.habitId == habit.id)
                  .length,
          };
        } catch (_) {
          // Habit rows remain useful, but an absent count must not look like 0.
          historyAvailable = false;
        }
      }

      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _habits = habits;
        _completionCounts = counts;
        _historyAvailable = historyAvailable;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loadError = 'Your habit goals could not be loaded.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'YOUR COMMITMENTS',
                            style: TextStyle(
                              color: AppColors.blue,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'My Goals',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _isLoading ? null : _loadGoals,
                      tooltip: 'Refresh',
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text(
                  'Your saved habits are the goals you are working toward.',
                  style: TextStyle(color: AppColors.muted, height: 1.4),
                ),
              ),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _habits.isEmpty && _loadError == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.blue),
      );
    }

    if (_loadError != null) {
      return _MessageState(
        icon: Icons.cloud_off_rounded,
        message: _loadError!,
        actionLabel: 'Try again',
        onAction: _loadGoals,
      );
    }

    if (_habits.isEmpty) {
      return const _MessageState(
        icon: Icons.track_changes_rounded,
        message: 'No habit-based goals yet.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadGoals,
      color: AppColors.blue,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        itemCount: _habits.length + (_isLoading ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (_isLoading && index == 0) {
            return const LinearProgressIndicator(color: AppColors.blue);
          }
          final habit = _habits[index - (_isLoading ? 1 : 0)];
          return _GoalHabitCard(
            habit: habit,
            completionCount: _historyAvailable
                ? _completionCounts[habit.id]
                : null,
          );
        },
      ),
    );
  }
}

class _GoalHabitCard extends StatelessWidget {
  const _GoalHabitCard({required this.habit, required this.completionCount});

  final Habit habit;
  final int? completionCount;

  @override
  Widget build(BuildContext context) {
    final color = habitCategoryColor(habit.category);
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(habitCategoryIcon(habit.category), color: color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${habit.category} · ${habit.frequency}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 7),
                Text(
                  completionCount == null
                      ? 'Completion history unavailable'
                      : '$completionCount recorded '
                            '${completionCount == 1 ? 'completion' : 'completions'}',
                  style: const TextStyle(color: AppColors.faint, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.muted, size: 38),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
