import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../services/habit_service.dart';
import 'add_habit_screen.dart';
import '../widgets/habit_card.dart';
import '../widgets/premium_ui.dart';
import 'statistics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final HabitService habitService = HabitService();

  List<Habit> habits = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    loadHabits();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Refresh habits whenever the app becomes active again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      loadHabits();
    }
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

      setState(() {
        isLoading = false;
      });

      showMessage('Failed to load habits.');
    }
  }

  Future<void> completeHabit(Habit habit) async {
    try {
      await habitService.completeHabit(habit);
      await loadHabits();
    } catch (e) {
      if (!mounted) return;

      showMessage('Failed to update habit.');
    }
  }

  Future<void> openAddHabit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddHabitScreen(),
      ),
    );

    await loadHabits();
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  bool isCompletedToday(Habit habit) {
    final today = DateTime.now().toIso8601String().split('T')[0];

    return habit.lastCompletedDate == today;
  }

  int get completedToday {
    return habits.where(isCompletedToday).length;
  }

  int get currentStreak {
    if (habits.isEmpty) {
      return 0;
    }

    int highest = 0;

    for (final habit in habits) {
      if (habit.streak > highest) {
        highest = habit.streak;
      }
    }

    return highest;
  }

  String get userName {
    final email = habitService.supabase.auth.currentUser?.email;

    if (email == null || email.isEmpty) {
      return 'there';
    }

    final name = email.split('@').first;

    if (name.isEmpty) {
      return 'there';
    }

    return name[0].toUpperCase() + name.substring(1);
  }

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
              : RefreshIndicator(
                  color: AppColors.blue,
                  backgroundColor: AppColors.surfaceRaised,
                  onRefresh: loadHabits,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildProgressCard(),
                      const SizedBox(height: 14),
                      _buildQuickStats(),
                      const SizedBox(height: 27),
                      _buildTodayHeader(),
                      const SizedBox(height: 14),
                      if (habits.isEmpty)
                        _buildEmptyState()
                      else
                        ...habits.map(_buildHabitItem),
                    ],
                  ),
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: openAddHabit,
        backgroundColor: AppColors.violet,
        foregroundColor: Colors.white,
        elevation: 8,
        tooltip: 'Add a habit',
        child: const Icon(
          Icons.add_rounded,
          size: 29,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'HABITQUEST',
                style: TextStyle(
                  color: AppColors.blue,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              Text(greeting,
                  style: const TextStyle(color: AppColors.muted, fontSize: 14)),
              const SizedBox(height: 2),
              Text(
                '$userName, let’s keep going.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontSize: 24),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
                colors: [AppColors.blue, AppColors.violet]),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
            boxShadow: [
              BoxShadow(
                  color: AppColors.blue.withValues(alpha: 0.18),
                  blurRadius: 16),
            ],
          ),
          child:
              const Icon(Icons.person_rounded, color: Colors.white, size: 25),
        ),
      ],
    );
  }

  Widget _buildProgressCard() {
    final progress = habits.isEmpty ? 0.0 : completedToday / habits.length;

    return GlassCard(
      glow: true,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Today's progress",
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  habits.isEmpty
                      ? 'Start today'
                      : '$completedToday of ${habits.length}',
                  style: const TextStyle(
                      color: AppColors.blue,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 116,
                height: 116,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: value,
                          strokeWidth: 9,
                          strokeCap: StrokeCap.round,
                          backgroundColor: const Color(0xFF2A303B),
                          valueColor:
                              const AlwaysStoppedAnimation(AppColors.blue),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$completedToday/${habits.length}',
                            style: const TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text),
                          ),
                          const Text('done today',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.muted)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 19),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProgressBreakdownLine(
                      icon: Icons.check_circle_rounded,
                      color: AppColors.green,
                      label: 'Completed',
                      value: '$completedToday',
                    ),
                    const SizedBox(height: 10),
                    _ProgressBreakdownLine(
                      icon: Icons.hourglass_bottom_rounded,
                      color: AppColors.orange,
                      label: 'Pending',
                      value: '${habits.length - completedToday}',
                    ),
                    const SizedBox(height: 13),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: const Color(0xFF2A303B),
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.violet),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _QuickStatCard(
            icon: Icons.local_fire_department_rounded,
            color: AppColors.orange,
            label: 'Best streak',
            value: '$currentStreak days',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickStatCard(
            icon: Icons.track_changes_rounded,
            color: AppColors.violet,
            label: 'Your habits',
            value: '${habits.length}',
          ),
        ),
      ],
    );
  }

  Widget _buildTodayHeader() {
    return SectionHeading(
      title: "Today's habits",
      trailing: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const StatisticsScreen()),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 5, horizontal: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Stats',
                  style: TextStyle(
                      color: AppColors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded,
                  color: AppColors.blue, size: 15),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHabitItem(Habit habit) {
    final completed = isCompletedToday(habit);
    return HabitCard(
      habit: habit,
      isCompleted: completed,
      onComplete: () => completeHabit(habit),
    );
  }

  Widget _buildEmptyState() {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.violet.withValues(alpha: 0.15),
            ),
            child: const Icon(Icons.flag_rounded,
                size: 30, color: AppColors.violet),
          ),
          const SizedBox(height: 15),
          const Text('No habits yet',
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 7),
          const Text(
            'Tap the + button to create your first habit.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  const _QuickStatCard({
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      borderRadius: 19,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 11)),
                const SizedBox(height: 4),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBreakdownLine extends StatelessWidget {
  const _ProgressBreakdownLine(
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
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 7),
        Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 11))),
        Text(value,
            style: const TextStyle(
                color: AppColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}
