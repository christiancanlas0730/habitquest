import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../models/habit_completion.dart';
import '../models/account_date.dart';
import '../models/productivity_analytics.dart';
import '../models/request_generation.dart';
import '../services/habit_service.dart';
import '../services/habit_repository.dart';
import '../widgets/premium_ui.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key, this.repository, this.accountClock});

  final HabitBrowserRepository? repository;
  final DateTime Function()? accountClock;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late final HabitBrowserRepository habitService =
      widget.repository ?? HabitService();
  List<Habit> habits = [];
  List<HabitCompletion> completions = [];
  bool isLoading = true;
  bool loadFailed = false;
  final _loadGeneration = RequestGeneration();
  AccountDateSource? _accountDateSource;
  AccountCalendarDate? _accountToday;

  @override
  void initState() {
    super.initState();
    loadHabits();
  }

  Future<void> loadHabits() async {
    final generation = _loadGeneration.begin();
    if (loadFailed && mounted) {
      setState(() {
        loadFailed = false;
        isLoading = true;
      });
    }
    try {
      final loaded = await habitService.loadCompletionHistory();
      if (!mounted || !_loadGeneration.isCurrent(generation)) return;
      AccountDateSource? dateSource;
      if (habitService is AccountDateRepository) {
        try {
          final settings = await (habitService as AccountDateRepository)
              .getCompletionTimeZoneSettings();
          if (settings != null) {
            dateSource = AccountDateSource.fromSettings(
              settings,
              clock: widget.accountClock,
            );
          }
        } catch (_) {
          dateSource = null;
        }
      }
      if (!mounted || !_loadGeneration.isCurrent(generation)) return;
      setState(() {
        habits = loaded.habits;
        completions = deduplicateHabitCompletions(loaded.completions);
        _accountDateSource = dateSource;
        _accountToday = dateSource?.today();
        isLoading = false;
        loadFailed = false;
      });
    } catch (e) {
      if (!mounted || !_loadGeneration.isCurrent(generation)) return;
      setState(() {
        isLoading = false;
        loadFailed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load statistics.')),
      );
    }
  }

  int get _recordedCompletions => completions.length;
  bool get _dateMetricsAvailable =>
      _accountDateSource != null && habits.every((habit) => habit.createdAt != null);

  int get _completedToday => completions
      .where((item) => item.completedOn == _accountToday?.key)
      .map((item) => item.habitId)
      .toSet()
      .length;
  int get _remainingToday => habits.length - _completedToday;
  int get _todayPercent =>
      habits.isEmpty ? 0 : ((_completedToday / habits.length) * 100).round();
  int get _highestStreak => habits.fold<int>(
    0,
    (highest, habit) =>
        habit.currentStreakOn(
              _accountToday!.utcDate,
              completionHistory: completions
                  .where((item) => item.habitId == habit.id)
                  .map((item) => item.calendarDate?.utcDate)
                  .whereType<DateTime>(),
            ) >
            highest
        ? habit.currentStreakOn(
            _accountToday!.utcDate,
            completionHistory: completions
                .where((item) => item.habitId == habit.id)
                .map((item) => item.calendarDate?.utcDate)
                .whereType<DateTime>(),
          )
        : highest,
  );
  DateTime get _weekStart => _accountToday!.utcDate.subtract(
    Duration(days: _accountToday!.utcDate.weekday - DateTime.monday),
  );
  DateTime get _monthStart =>
      DateTime.utc(_accountToday!.year, _accountToday!.month);
  ProductivityPeriodSummary get _weeklySummary =>
      ProductivityPeriodSummary.calculate(
        habits: habits,
        completions: completions,
        start: _weekStart,
        end: _accountToday!.utcDate,
        dateSource: _accountDateSource!,
      );
  ProductivityPeriodSummary get _monthlySummary =>
      ProductivityPeriodSummary.calculate(
        habits: habits,
        completions: completions,
        start: _monthStart,
        end: _accountToday!.utcDate,
        dateSource: _accountDateSource!,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PremiumBackground(
        child: SafeArea(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.blue),
                )
              : loadFailed
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Statistics could not be loaded.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      TextButton(
                        onPressed: loadHabits,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.blue,
                  backgroundColor: AppColors.surfaceRaised,
                  onRefresh: loadHabits,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                    children: [
                      const Text(
                        'YOUR MOMENTUM',
                        style: TextStyle(
                          color: AppColors.blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Statistics',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'A clear view of the progress your habits currently record.',
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                      const SizedBox(height: 19),
                      _buildTodayCard(),
                      const SizedBox(height: 13),
                      _buildPeriodSummaries(),
                      const SizedBox(height: 13),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.track_changes_rounded,
                              color: AppColors.violet,
                              label: 'Total habits',
                              value: '${habits.length}',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.local_fire_department_rounded,
                              color: AppColors.orange,
                              label: 'Highest current streak',
                              value: _dateMetricsAvailable
                                  ? '$_highestStreak days'
                                  : 'Unavailable',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _StatCard(
                        icon: Icons.event_available_rounded,
                        color: AppColors.green,
                        label: 'Recorded completions',
                        value: '$_recordedCompletions',
                      ),
                      const SizedBox(height: 23),
                      const SectionHeading(title: 'Habits by category'),
                      const SizedBox(height: 12),
                      _buildCategoryCard(),
                      const SizedBox(height: 14),
                      Text(
                        _dateMetricsAvailable
                            ? 'Recorded totals use server completion history. Scheduled rates use the account-local date and saved habit creation timestamps.'
                            : 'Recorded totals include available history. Date-based summaries require a valid account timezone and saved habit creation timestamps.',
                        style: TextStyle(
                          color: AppColors.faint,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildPeriodSummaries() {
    if (!_dateMetricsAvailable) {
      return const GlassCard(
        child: Text(
          'Weekly and monthly summaries are unavailable until the account date and habit creation dates can be resolved.',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      );
    }
    final week = _weeklySummary;
    final month = _monthlySummary;
    return GlassCard(
      child: Text(
        'This week: ${week.successfulOpportunities} of ${week.expectedCompletions} scheduled · ${(week.completionRate * 100).round()}%\n'
        'This month: ${month.successfulOpportunities} of ${month.expectedCompletions} scheduled · ${(month.completionRate * 100).round()}%',
        style: const TextStyle(color: AppColors.muted, fontSize: 12),
      ),
    );
  }

  Widget _buildTodayCard() {
    if (!_dateMetricsAvailable) {
      return const GlassCard(
        glow: true,
        child: Text(
          'Today’s completion is unavailable until the account timezone and habit creation dates can be resolved.',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      );
    }
    return GlassCard(
      glow: true,
      child: Text(
        'Today: $_completedToday of ${habits.length} habits ($_todayPercent%). $_remainingToday remaining.',
        style: const TextStyle(color: AppColors.text, fontSize: 14),
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
    final sorted =
        categories
            .where(
              (category) => habits.any((habit) => habit.category == category),
            )
            .toList()
          ..sort();
    if (sorted.isEmpty) {
      return GlassCard(
        child: const Text(
          'Create habits to see how they’re grouped here.',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      );
    }
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(17, 13, 17, 13),
      child: Column(
        children: sorted.map((category) {
          final count = habits
              .where((habit) => habit.category == category)
              .length;
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
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '$count',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

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
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

