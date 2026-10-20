import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../services/habit_service.dart';
import '../widgets/premium_ui.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final HabitService habitService = HabitService();
  List<Habit> habits = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadHabits();
  }

  Future<void> loadHabits() async {
    try {
      final result = await habitService.getHabits();
      if (!mounted) return;
      setState(() {
        habits = result;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load statistics.')),
      );
    }
  }

  bool _isCompletedToday(Habit habit) {
    final today = DateTime.now().toIso8601String().split('T')[0];
    return habit.lastCompletedDate == today;
  }

  int get _completedToday => habits.where(_isCompletedToday).length;
  int get _remainingToday => habits.length - _completedToday;
  int get _highestStreak => habits.fold<int>(
      0, (highest, habit) => habit.streak > highest ? habit.streak : highest);
  Habit? get _streakLeader => habits.isEmpty
      ? null
      : habits.reduce((a, b) => a.streak >= b.streak ? a : b);
  int get _todayPercent =>
      habits.isEmpty ? 0 : ((_completedToday / habits.length) * 100).round();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PremiumBackground(
        child: SafeArea(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.blue))
              : RefreshIndicator(
                  color: AppColors.blue,
                  backgroundColor: AppColors.surfaceRaised,
                  onRefresh: loadHabits,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                    children: [
                      const Text('YOUR MOMENTUM',
                          style: TextStyle(
                              color: AppColors.blue,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2)),
                      const SizedBox(height: 8),
                      Text('Statistics',
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 5),
                      const Text(
                          'A clear view of the progress your habits currently record.',
                          style:
                              TextStyle(color: AppColors.muted, fontSize: 13)),
                      const SizedBox(height: 19),
                      _buildTodayCard(),
                      const SizedBox(height: 13),
                      Row(
                        children: [
                          Expanded(
                              child: _StatCard(
                                  icon: Icons.track_changes_rounded,
                                  color: AppColors.violet,
                                  label: 'Total habits',
                                  value: '${habits.length}')),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _StatCard(
                                  icon: Icons.local_fire_department_rounded,
                                  color: AppColors.orange,
                                  label: 'Highest streak',
                                  value: '$_highestStreak days')),
                        ],
                      ),
                      if (_streakLeader != null) ...[
                        const SizedBox(height: 13),
                        GlassCard(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 41,
                                height: 41,
                                decoration: BoxDecoration(
                                    color: AppColors.orange
                                        .withValues(alpha: 0.13),
                                    borderRadius: BorderRadius.circular(13)),
                                child: const Icon(
                                    Icons.local_fire_department_rounded,
                                    color: AppColors.orange,
                                    size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Streak leader',
                                        style: TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 11)),
                                    const SizedBox(height: 4),
                                    Text(_streakLeader!.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: AppColors.text,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                              Text('$_highestStreak days',
                                  style: const TextStyle(
                                      color: AppColors.orange,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 23),
                      const SectionHeading(title: 'Habits by category'),
                      const SizedBox(height: 12),
                      _buildCategoryCard(),
                      const SizedBox(height: 14),
                      const Text(
                        'Daily completion uses each habit’s latest saved completion date. The app does not currently keep older daily history or weekly totals.',
                        style: TextStyle(
                            color: AppColors.faint, fontSize: 11, height: 1.4),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildTodayCard() {
    final ratio = habits.isEmpty ? 0.0 : _completedToday / habits.length;
    return GlassCard(
      glow: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Today's completion",
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 17),
          Row(
            children: [
              SizedBox(
                width: 112,
                height: 112,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: ratio,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                        backgroundColor: const Color(0xFF2A303B),
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.blue),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$_todayPercent%',
                            style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 24,
                                fontWeight: FontWeight.w700)),
                        const Text('today',
                            style: TextStyle(
                                color: AppColors.muted, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 19),
              Expanded(
                child: Column(
                  children: [
                    _BreakdownLine(
                        icon: Icons.check_circle_rounded,
                        color: AppColors.green,
                        label: 'Completed',
                        value: '$_completedToday'),
                    const SizedBox(height: 14),
                    _BreakdownLine(
                        icon: Icons.timelapse_rounded,
                        color: AppColors.orange,
                        label: 'Remaining',
                        value: '$_remainingToday'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard() {
    final categories = <String>{
      'Study',
      'Health',
      'Fitness',
      'Personal',
      ...habits.map((habit) => habit.category),
    }.toList();
    final sorted = categories
        .where((category) => habits.any((habit) => habit.category == category))
        .toList()
      ..sort();
    if (sorted.isEmpty) {
      return GlassCard(
        child: const Text('Create habits to see how they’re grouped here.',
            style: TextStyle(color: AppColors.muted, fontSize: 13)),
      );
    }
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(17, 13, 17, 13),
      child: Column(
        children: sorted.map((category) {
          final count =
              habits.where((habit) => habit.category == category).length;
          final share = count / habits.length;
          final color = habitCategoryColor(category);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(habitCategoryIcon(category), color: color, size: 17),
                    const SizedBox(width: 9),
                    Expanded(
                        child: Text(category,
                            style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 13,
                                fontWeight: FontWeight.w600))),
                    Text('$count',
                        style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 5,
                    backgroundColor: const Color(0xFF2A303B),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.icon,
      required this.color,
      required this.label,
      required this.value});

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(15),
      borderRadius: 19,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 10),
          Text(label,
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

class _BreakdownLine extends StatelessWidget {
  const _BreakdownLine(
      {required this.icon,
      required this.color,
      required this.label,
      required this.value});

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(width: 7),
        Expanded(
            child: Text(label,
                style: const TextStyle(color: AppColors.muted, fontSize: 12))),
        Text(value,
            style: const TextStyle(
                color: AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}
