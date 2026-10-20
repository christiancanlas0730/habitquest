import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../models/account_date.dart';
import '../models/habit_completion.dart';
import '../services/habit_service.dart';
import '../services/habit_repository.dart';
import '../widgets/habit_card.dart';
import '../widgets/premium_ui.dart';
import 'habit_detail_screen.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key, this.repository});

  final HabitRepository? repository;

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  late final HabitRepository habitService = widget.repository ?? HabitService();
  List<Habit> habits = [];
  bool isLoading = true;
  bool loadFailed = false;
  String selectedTab = 'All';
  int _loadGeneration = 0;
  AccountDateSource? _accountDateSource;
  Map<String, List<DateTime>> _completionDates = const {};
  bool _completionHistoryAvailable = true;

  @override
  void initState() {
    super.initState();
    loadHabits();
  }

  Future<void> loadHabits() async {
    final generation = ++_loadGeneration;
    try {
      final data = await habitService.getHabits();
      Map<String, List<DateTime>> completionDates = const {};
      var completionHistoryAvailable = true;
      if (data.isNotEmpty) {
        try {
          final rows = await habitService.getCompletionHistory(
            data.map((habit) => habit.id),
          );
          final uniqueRows = deduplicateHabitCompletions(rows);
          completionDates = {
            for (final habit in data)
              habit.id: uniqueRows
                  .where((row) => row.habitId == habit.id)
                  .map((row) => row.calendarDate?.utcDate)
                  .whereType<DateTime>()
                  .toList(),
          };
        } catch (_) {
          completionDates = const {};
          completionHistoryAvailable = false;
        }
      }
      AccountDateSource? dateSource;
      if (habitService is AccountDateRepository) {
        try {
          final settings = await (habitService as AccountDateRepository)
              .getCompletionTimeZoneSettings();
          if (settings != null) {
            dateSource = AccountDateSource.fromSettings(settings);
          }
        } catch (_) {
          dateSource = null;
        }
      }
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        habits = data;
        _completionDates = completionDates;
        _completionHistoryAvailable = completionHistoryAvailable;
        _accountDateSource = dateSource;
        if (dateSource == null) selectedTab = 'All';
        isLoading = false;
        loadFailed = false;
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        isLoading = false;
        loadFailed = habits.isEmpty;
      });
      showMessage('Failed to load habits.');
    }
  }

  Future<void> openHabitDetail(Habit habit) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HabitDetailScreen(
          habit: habit,
          repository: habitService is HabitDetailRepository
              ? habitService as HabitDetailRepository
              : null,
        ),
      ),
    );
    await loadHabits();
    if (!mounted) return;
    if (result == true) showMessage('Habit deleted successfully.');
  }

  List<Habit> get filteredHabits {
    final today = _accountDateSource?.today();
    if (today == null) return habits;
    if (selectedTab == 'Active') {
      return habits
          .where((habit) => habit.lastCompletedDate != today.key)
          .toList();
    }
    if (selectedTab == 'Completed') {
      return habits
          .where((habit) => habit.lastCompletedDate == today.key)
          .toList();
    }
    return habits;
  }

  int? get completedTodayCount {
    final today = _accountDateSource?.today();
    if (today == null) return null;
    return habits
        .where((habit) => habit.lastCompletedDate == today.key)
        .length;
  }

  int? get bestCurrentStreak {
    final today = _accountDateSource?.today();
    if (today == null || habits.isEmpty) return today == null ? null : 0;
    if (!_completionHistoryAvailable) return null;
    if (habits.any(
      (habit) =>
          habit.frequency == 'Twice a week' &&
          !_completionDates.containsKey(habit.id),
    )) {
      return null;
    }
    return habits
        .map((habit) => habit.currentStreakOn(
          today.utcDate,
          completionHistory: _completionDates[habit.id],
        ))
        .reduce((a, b) => a > b ? a : b);
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleHabits = filteredHabits;
    final wideLayout = MediaQuery.sizeOf(context).width >= 720;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  wideLayout ? 32 : 21,
                  20,
                  wideLayout ? 32 : 21,
                  20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YOUR ROUTINES',
                      style: TextStyle(
                        color: AppColors.blue,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'My Habits',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${habits.length} routines in your journey',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: wideLayout ? 32 : 20),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xAA10141B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      _buildTab('All'),
                      const SizedBox(width: 5),
                      _buildTab('Active', enabled: _accountDateSource != null),
                      const SizedBox(width: 5),
                      _buildTab('Completed', enabled: _accountDateSource != null),
                    ],
                  ),
                ),
              ),
              if (_accountDateSource == null)
                const Padding(
                  padding: EdgeInsets.fromLTRB(22, 8, 22, 0),
                  child: Text(
                    'Today filters and streaks are unavailable until the account date can be resolved.',
                    style: TextStyle(color: AppColors.faint, fontSize: 11),
                  ),
                ),
              const SizedBox(height: 17),
              Expanded(
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
                              'Habits could not be loaded.',
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
                        child: visibleHabits.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  22,
                                  20,
                                  22,
                                  24,
                                ),
                                children: [
                                  _buildSummaryCard(),
                                  const SizedBox(height: 13),
                                  GlassCard(
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline_rounded,
                                          size: 42,
                                          color: AppColors.blue.withValues(
                                            alpha: 0.85,
                                          ),
                                        ),
                                        const SizedBox(height: 13),
                                        Text(
                                          selectedTab == 'All'
                                              ? 'No habits yet'
                                              : 'No $selectedTab habits',
                                          style: const TextStyle(
                                            color: AppColors.text,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 7),
                                        const Text(
                                          'Use the Add habit button to get started.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.fromLTRB(
                                  wideLayout ? 32 : 20,
                                  0,
                                  wideLayout ? 32 : 20,
                                  24,
                                ),
                                itemCount: visibleHabits.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == 0) return _buildSummaryCard();
                                  final itemIndex = index - 1;
                                  if (wideLayout) {
                                    if (itemIndex.isOdd) {
                                      return const SizedBox.shrink();
                                    }
                                    final secondIndex = itemIndex + 1;
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: _habitCard(
                                            visibleHabits[itemIndex],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child:
                                              secondIndex < visibleHabits.length
                                              ? _habitCard(
                                                  visibleHabits[secondIndex],
                                                )
                                              : const SizedBox.shrink(),
                                        ),
                                      ],
                                    );
                                  }
                                  return _habitCard(visibleHabits[itemIndex]);
                                },
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _habitCard(Habit habit) => HabitCard(
    habit: habit,
    showStreakRing: true,
    dateStatusUnavailable: _accountDateSource == null,
    accountLocalDate: _accountDateSource?.today().utcDate,
    completionHistory: _completionDates[habit.id],
    streakUnavailable: !_completionHistoryAvailable &&
        habit.frequency == 'Twice a week',
    isCompleted: _accountDateSource == null
        ? null
        : habit.lastCompletedDate == _accountDateSource!.today().key,
    onTap: () => openHabitDetail(habit),
  );

  Widget _buildSummaryCard() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: _ListStat(
              icon: Icons.check_circle_outline_rounded,
              color: AppColors.blue,
              label: 'Done today',
              value: completedTodayCount == null
                  ? 'Unavailable'
                  : '$completedTodayCount / ${habits.length}',
            ),
          ),
          Container(width: 1, height: 38, color: AppColors.border),
          const SizedBox(width: 13),
          Expanded(
            child: _ListStat(
              icon: Icons.local_fire_department_rounded,
              color: AppColors.orange,
              label: 'Best current streak',
              value: bestCurrentStreak == null
                  ? 'Unavailable'
                  : '$bestCurrentStreak days',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, {bool enabled = true}) {
    final isSelected = selectedTab == title;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? () => setState(() => selectedTab = title) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [AppColors.blue, AppColors.violet],
                    )
                  : null,
              border: Border.all(
                color: isSelected ? Colors.transparent : AppColors.border,
              ),
              color: isSelected ? null : const Color(0x661A202A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : enabled
                    ? AppColors.muted
                    : AppColors.faint,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ListStat extends StatelessWidget {
  const _ListStat({
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
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 10),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
