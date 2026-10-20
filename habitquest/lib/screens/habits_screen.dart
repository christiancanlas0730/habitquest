import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../services/habit_service.dart';
import '../widgets/habit_card.dart';
import '../widgets/premium_ui.dart';
import 'habit_detail_screen.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final HabitService habitService = HabitService();
  List<Habit> habits = [];
  bool isLoading = true;
  String selectedTab = 'All';

  @override
  void initState() {
    super.initState();
    loadHabits();
  }

  Future<void> loadHabits() async {
    try {
      final data = await habitService.getHabits();
      if (!mounted) return;
      setState(() {
        habits = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
      showMessage('Failed to load habits.');
    }
  }

  Future<void> openHabitDetail(Habit habit) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HabitDetailScreen(habit: habit)),
    );
    await loadHabits();
    if (!mounted) return;
    if (result == true) showMessage('Habit deleted successfully.');
  }

  int get completedTodayCount {
    final today = DateTime.now().toIso8601String().split('T')[0];
    return habits.where((habit) => habit.lastCompletedDate == today).length;
  }

  int get bestCurrentStreak {
    if (habits.isEmpty) return 0;
    return habits.map((habit) => habit.streak).reduce((a, b) => a > b ? a : b);
  }

  List<Habit> get filteredHabits {
    if (selectedTab == 'Active') {
      return habits.where((habit) => habit.lastCompletedDate == null).toList();
    }
    if (selectedTab == 'Completed') {
      return habits.where((habit) => habit.lastCompletedDate != null).toList();
    }
    return habits;
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: PremiumBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(21, 20, 21, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YOUR ROUTINES',
                      style: TextStyle(
                          color: AppColors.blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2),
                    ),
                    const SizedBox(height: 8),
                    Text('My Habits',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 5),
                    Text('${habits.length} routines in your journey',
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 13)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
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
                      _buildTab('Active'),
                      const SizedBox(width: 5),
                      _buildTab('Completed'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 17),
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.blue))
                    : RefreshIndicator(
                        color: AppColors.blue,
                        backgroundColor: AppColors.surfaceRaised,
                        onRefresh: loadHabits,
                        child: visibleHabits.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.fromLTRB(22, 20, 22, 24),
                                children: [
                                  _buildSummaryCard(),
                                  const SizedBox(height: 13),
                                  GlassCard(
                                    child: Column(
                                      children: [
                                        Icon(Icons.check_circle_outline_rounded,
                                            size: 42,
                                            color: AppColors.blue
                                                .withValues(alpha: 0.85)),
                                        const SizedBox(height: 13),
                                        Text(
                                          selectedTab == 'All'
                                              ? 'No habits yet'
                                              : 'No $selectedTab habits',
                                          style: const TextStyle(
                                              color: AppColors.text,
                                              fontSize: 17,
                                              fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 7),
                                        const Text(
                                            'Add a habit from the Home screen.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                color: AppColors.muted,
                                                fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.fromLTRB(20, 0, 20, 24),
                                itemCount: visibleHabits.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == 0) return _buildSummaryCard();
                                  final habit = visibleHabits[index - 1];
                                  return HabitCard(
                                    habit: habit,
                                    showStreakRing: true,
                                    isCompleted:
                                        habit.lastCompletedDate != null,
                                    onTap: () => openHabitDetail(habit),
                                  );
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
              value: '$completedTodayCount / ${habits.length}',
            ),
          ),
          Container(width: 1, height: 38, color: AppColors.border),
          const SizedBox(width: 13),
          Expanded(
            child: _ListStat(
              icon: Icons.local_fire_department_rounded,
              color: AppColors.orange,
              label: 'Best current streak',
              value: '$bestCurrentStreak days',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title) {
    final isSelected = selectedTab == title;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedTab = title),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [AppColors.blue, AppColors.violet])
                : null,
            border: Border.all(
                color: isSelected ? Colors.transparent : AppColors.border),
            color: isSelected ? null : const Color(0x661A202A),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: isSelected ? Colors.white : AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _ListStat extends StatelessWidget {
  const _ListStat(
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
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 10)),
              const SizedBox(height: 3),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}
