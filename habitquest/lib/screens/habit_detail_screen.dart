import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../services/habit_service.dart';
import '../widgets/premium_ui.dart';
import 'edit_habit_screen.dart';

class HabitDetailScreen extends StatefulWidget {
  final Habit habit;

  const HabitDetailScreen({super.key, required this.habit});

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  final HabitService habitService = HabitService();
  late Habit habit;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    habit = widget.habit;
  }

  bool get completedToday {
    final today = DateTime.now().toIso8601String().split('T')[0];
    return habit.lastCompletedDate == today;
  }

  Future<void> toggleComplete() async {
    if (isLoading) return;
    setState(() {
      isLoading = true;
    });
    try {
      if (completedToday) {
        showMessage('Habit is already completed today.');
      } else {
        await habitService.completeHabit(habit);
        if (!mounted) return;
        final today = DateTime.now().toIso8601String().split('T')[0];
        setState(() {
          habit = Habit(
            id: habit.id,
            userId: habit.userId,
            name: habit.name,
            category: habit.category,
            frequency: habit.frequency,
            streak: habit.streak + 1,
            lastCompletedDate: today,
            createdAt: habit.createdAt,
          );
        });
        showMessage('Habit completed!');
      }
    } catch (e) {
      if (!mounted) return;
      showMessage('Failed to update habit.');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> deleteHabit() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceRaised,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text('Delete habit?',
              style: TextStyle(
                  color: AppColors.text, fontWeight: FontWeight.w700)),
          content: Text('Are you sure you want to delete "${habit.name}"?',
              style: const TextStyle(color: AppColors.muted, height: 1.45)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.muted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Delete', style: TextStyle(color: AppColors.red)),
            ),
          ],
        );
      },
    );
    if (shouldDelete != true) return;
    setState(() {
      isLoading = true;
    });
    try {
      await habitService.deleteHabit(habit.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      showMessage('Failed to delete habit.');
    }
  }

  Future<void> editHabit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditHabitScreen(habit: habit)),
    );
    if (result is Habit) {
      if (!mounted) return;
      setState(() {
        habit = result;
      });
    } else if (result == true) {
      if (!mounted) return;
      Navigator.pop(context, true);
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final accent = habitCategoryColor(habit.category);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 5, 10, 3),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: AppColors.text),
                    ),
                    const Expanded(
                      child: Text('Habit details',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                      tooltip: 'Edit habit',
                      onPressed: isLoading ? null : editHabit,
                      icon: const Icon(Icons.edit_rounded,
                          color: AppColors.blue, size: 20),
                    ),
                    IconButton(
                      tooltip: 'Delete habit',
                      onPressed: isLoading ? null : deleteHabit,
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.red, size: 21),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  child: Column(
                    children: [
                      GlassCard(
                        glow: true,
                        padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
                        child: Column(
                          children: [
                            Container(
                              width: 92,
                              height: 92,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accent.withValues(alpha: 0.13),
                                border: Border.all(
                                    color: accent.withValues(alpha: 0.45),
                                    width: 1.3),
                                boxShadow: [
                                  BoxShadow(
                                      color: accent.withValues(alpha: 0.16),
                                      blurRadius: 22)
                                ],
                              ),
                              child: Icon(habitCategoryIcon(habit.category),
                                  color: accent, size: 42),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              habit.name,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontSize: 25),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                    color: accent.withValues(alpha: 0.18)),
                              ),
                              child: Text(
                                  '${habit.category}  ·  ${habit.frequency}',
                                  style: TextStyle(
                                      color: accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              icon: Icons.local_fire_department_rounded,
                              color: AppColors.orange,
                              title: 'Current streak',
                              value:
                                  '${habit.streak} ${habit.streak == 1 ? 'day' : 'days'}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MetricCard(
                              icon: completedToday
                                  ? Icons.check_circle_rounded
                                  : Icons.timelapse_rounded,
                              color: completedToday
                                  ? AppColors.green
                                  : AppColors.blue,
                              title: "Today's status",
                              value: completedToday ? 'Complete' : 'Not yet',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      GlassCard(
                        padding: const EdgeInsets.fromLTRB(17, 6, 17, 6),
                        child: Column(
                          children: [
                            _DetailRow(
                                icon: Icons.repeat_rounded,
                                title: 'Frequency',
                                value: habit.frequency),
                            const Divider(height: 1, color: AppColors.border),
                            _DetailRow(
                                icon: Icons.category_outlined,
                                title: 'Category',
                                value: habit.category),
                            const Divider(height: 1, color: AppColors.border),
                            _DetailRow(
                              icon: completedToday
                                  ? Icons.check_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              title: 'Today',
                              value: completedToday
                                  ? 'Completed'
                                  : 'Not completed yet',
                              valueColor: completedToday
                                  ? AppColors.green
                                  : AppColors.muted,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      GradientActionButton(
                        label: completedToday
                            ? 'Completed today'
                            : 'Mark as complete',
                        icon: completedToday
                            ? Icons.check_circle_rounded
                            : Icons.check_rounded,
                        isLoading: isLoading,
                        onPressed:
                            isLoading || completedToday ? null : toggleComplete,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(
      {required this.icon,
      required this.color,
      required this.title,
      required this.value});

  final IconData icon;
  final Color color;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(15),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 10),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(
      {required this.icon,
      required this.title,
      required this.value,
      this.valueColor});

  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
                color: AppColors.violet.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.violet, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(title,
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 13))),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: valueColor ?? AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
