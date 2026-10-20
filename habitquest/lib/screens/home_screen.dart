import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/habit.dart';
import '../models/account_date.dart';
import '../models/gamification.dart';
import '../services/habit_service.dart';
import '../services/habit_repository.dart';
import 'add_habit_screen.dart';
import '../widgets/habit_card.dart';
import '../widgets/premium_ui.dart';
import 'statistics_screen.dart';
import 'achievements_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.repository});

  final HabitHomeRepository? repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final HabitHomeRepository habitService =
      widget.repository ?? HabitService();

  List<Habit> habits = [];
  bool isLoading = true;
  bool _habitsLoadFailed = false;
  GamificationProgress? gamification;
  int? recentXpEarned;
  String? _optionalDataNotice;
  bool _completionTimeZoneReady = false;
  AccountDateSource? _accountDateSource;
  String? _completionTimeZoneIssue;
  final Set<String> _completingHabitIds = {};
  int _loadGeneration = 0;
  int _timeZoneCheckGeneration = 0;
  bool _dashboardCanRetry = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    loadHabits();
    _checkCompletionTimeZone();
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
      _checkCompletionTimeZone();
    }
  }

  Future<void> loadHabits() async {
    final generation = ++_loadGeneration;
    if (mounted) {
      setState(() {
        if (habits.isEmpty) {
          isLoading = true;
          _habitsLoadFailed = false;
        }
        gamification = null;
        _dashboardCanRetry = false;
        _optionalDataNotice = habits.isEmpty
            ? null
            : 'Refreshing dashboard data…';
      });
    }
    late final List<Habit> loadedHabits;
    try {
      loadedHabits = await habitService.getHabits();
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        isLoading = false;
        _habitsLoadFailed = habits.isEmpty;
        _optionalDataNotice = habits.isEmpty
            ? null
            : 'Refresh failed. Showing previously loaded habits; player progress is unavailable.';
        _dashboardCanRetry = habits.isNotEmpty;
      });
      return;
    }

    var recoveredHabits = loadedHabits;
    String? recoveryNotice;
    try {
      recoveredHabits = await habitService.reconcileCompletionHistory(
        loadedHabits,
      );
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      recoveryNotice =
          'Habits are available, but completion recovery failed (${_errorCode(error)}). Refresh to retry.';
    }

    if (!mounted || generation != _loadGeneration) return;
    setState(() {
      habits = recoveredHabits;
      isLoading = false;
      _habitsLoadFailed = false;
      _optionalDataNotice = recoveryNotice ?? 'Loading player progress…';
      _dashboardCanRetry = recoveryNotice != null;
    });

    try {
      final progress = await habitService.getGamificationProgress(
        habitIds: recoveredHabits.map((habit) => habit.id),
        localDate: _accountDateSource?.today().utcDate,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        gamification = progress;
        _optionalDataNotice = recoveryNotice;
        _dashboardCanRetry = recoveryNotice != null;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      final reason = _errorCode(error);
      final progressNotice =
          error is PostgrestException &&
              (error.code == 'PGRST205' || error.code == '42P01')
          ? 'XP and achievements need the gamification migration.'
          : 'XP and achievement data failed to load ($reason). Pull to refresh to retry.';
      setState(() {
        _optionalDataNotice = recoveryNotice == null
            ? 'Habits are available. $progressNotice'
            : '$recoveryNotice $progressNotice';
        _dashboardCanRetry = true;
      });
    }
  }

  String _errorCode(Object error) => error is PostgrestException
      ? 'database error ${error.code ?? 'unknown'}'
      : 'unexpected error (${error.runtimeType})';

  Future<void> _checkCompletionTimeZone() async {
    final generation = ++_timeZoneCheckGeneration;
    final previous = _accountDateSource?.settings;
    try {
      final settings = await habitService.getCompletionTimeZoneSettings();
      final source = settings == null
          ? null
          : AccountDateSource.fromSettings(settings);
      if (!mounted || generation != _timeZoneCheckGeneration) return;
      final changed = previous?.timeZone != settings?.timeZone ||
          previous?.updatedAt != settings?.updatedAt;
      setState(() {
        _accountDateSource = source;
        _completionTimeZoneReady = source != null;
        _completionTimeZoneIssue = source != null
            ? null
            : 'Set your completion timezone in Profile before completing habits.';
      });
      if (changed && (previous != null || !isLoading)) {
        unawaited(loadHabits());
      }
    } catch (error) {
      if (!mounted || generation != _timeZoneCheckGeneration) return;
      setState(() {
        _accountDateSource = null;
        _completionTimeZoneReady = false;
        _completionTimeZoneIssue = completionTimeZoneErrorMessage(
          error,
          fallback:
              'Timezone settings could not be verified. Retry or open Profile settings.',
        );
      });
      if (previous != null) unawaited(loadHabits());
    }
  }

  Future<void> _openTimeZoneSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
    if (mounted) await _checkCompletionTimeZone();
  }

  Future<void> completeHabit(Habit habit) async {
    if (!_completionTimeZoneReady || !_completingHabitIds.add(habit.id)) {
      return;
    }
    try {
      if (mounted) setState(() {});
      final completion = await habitService.completeHabit(habit);
      if (!mounted) return;
      final reward = completion.reward;
      setState(() => recentXpEarned = reward?.earnedXp ?? 0);
      await loadHabits();
      if (!mounted) return;
      if (completion.rewardPending) {
        showMessage(
          'Habit saved. Reward processing is unavailable; refresh to retry.',
        );
      } else if (reward != null && reward.earnedXp > 0) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('+${reward.earnedXp} XP earned')),
          );
      }
    } catch (e) {
      if (!mounted) return;

      showMessage(
        e is CompletionSummaryUpdateException
            ? e.message
            : e is CompletionTimeZoneRequiredException
            ? e.message
            : completionTimeZoneErrorMessage(
                e,
                fallback: 'Failed to update habit.',
              ),
      );
      if (e is CompletionSummaryUpdateException) await loadHabits();
    } finally {
      _completingHabitIds.remove(habit.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> openAddHabit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddHabitScreen()),
    );

    await loadHabits();
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  int? get completedToday => gamification?.completedToday;

  String get userName {
    final email = habitService.currentUserEmail;

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
    final wideLayout = MediaQuery.sizeOf(context).width >= 720;
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
                  onRefresh: () async {
                    await loadHabits();
                    await _checkCompletionTimeZone();
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      wideLayout ? 32 : 20,
                      18,
                      wideLayout ? 32 : 20,
                      48,
                    ),
                    children: [
                      if (_completionTimeZoneIssue != null) ...[
                        _buildCompletionTimeZoneNotice(),
                        const SizedBox(height: 14),
                      ],
                      if (wideLayout) ...[
                        _buildHeader(),
                        if (_optionalDataNotice != null) ...[
                          const SizedBox(height: 14),
                          _buildOptionalDataNotice(),
                        ],
                        const SizedBox(height: 24),
                        _buildProgressCard(),
                        const SizedBox(height: 14),
                        _buildPlayerCard(),
                        const SizedBox(height: 14),
                        _buildDailyQuests(),
                        const SizedBox(height: 14),
                        _buildQuickStats(),
                        const SizedBox(height: 27),
                        _buildTodayHeader(),
                        const SizedBox(height: 14),
                        if (_habitsLoadFailed)
                          _buildHabitsLoadFailure()
                        else if (habits.isEmpty)
                          _buildEmptyState()
                        else
                          Wrap(
                            spacing: 12,
                            runSpacing: 0,
                            children: habits.map((habit) {
                              return SizedBox(
                                width:
                                    (MediaQuery.sizeOf(context).width - 120) /
                                    2,
                                child: _buildHabitItem(habit),
                              );
                            }).toList(),
                          ),
                      ] else ...[
                        _buildHeader(),
                        if (_optionalDataNotice != null) ...[
                          const SizedBox(height: 14),
                          _buildOptionalDataNotice(),
                        ],
                        const SizedBox(height: 24),
                        _buildProgressCard(),
                        const SizedBox(height: 14),
                        _buildPlayerCard(),
                        const SizedBox(height: 14),
                        _buildDailyQuests(),
                        const SizedBox(height: 14),
                        _buildQuickStats(),
                        const SizedBox(height: 27),
                        _buildTodayHeader(),
                        const SizedBox(height: 14),
                        if (_habitsLoadFailed)
                          _buildHabitsLoadFailure()
                        else if (habits.isEmpty)
                          _buildEmptyState()
                        else
                          ...habits.map(_buildHabitItem),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildOptionalDataNotice() => GlassCard(
    padding: const EdgeInsets.all(13),
    child: Row(
      children: [
        const Icon(Icons.info_outline_rounded, color: AppColors.orange),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            _optionalDataNotice!,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ),
        if (_dashboardCanRetry)
          TextButton(onPressed: loadHabits, child: const Text('Retry')),
      ],
    ),
  );

  Widget _buildCompletionTimeZoneNotice() => GlassCard(
    padding: const EdgeInsets.all(13),
    child: Row(
      children: [
        const Icon(Icons.public_rounded, color: AppColors.orange),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            _completionTimeZoneIssue!,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ),
        TextButton(
          onPressed: _openTimeZoneSettings,
          child: const Text('Set up'),
        ),
      ],
    ),
  );

  Widget _buildHeader() {
    final hour = _accountDateSource?.at(DateTime.now()).hour;
    final greeting = hour == null
        ? 'Welcome back'
        : hour < 12
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
              Text(
                greeting,
                style: const TextStyle(color: AppColors.muted, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                '$userName, let’s keep going.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(fontSize: 24),
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
              colors: [AppColors.blue, AppColors.violet],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
            boxShadow: [
              BoxShadow(
                color: AppColors.blue.withValues(alpha: 0.18),
                blurRadius: 16,
              ),
            ],
          ),
          child: const Icon(
            Icons.person_rounded,
            color: Colors.white,
            size: 25,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCard() {
    final count = completedToday;
    final progress = count == null || habits.isEmpty
        ? null
        : (count / habits.length).clamp(0.0, 1.0).toDouble();

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
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  habits.isEmpty
                      ? 'Start today'
                      : count == null
                      ? 'Date unavailable'
                      : '$count of ${habits.length}',
                  style: const TextStyle(
                    color: AppColors.blue,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: MediaQuery.sizeOf(context).width < 360 ? 96 : 116,
                height: MediaQuery.sizeOf(context).width < 360 ? 96 : 116,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: progress == null
                          ? CircularProgressIndicator(
                              value: 0,
                              strokeWidth: 9,
                              strokeCap: StrokeCap.round,
                              backgroundColor: const Color(0xFF2A303B),
                              valueColor: AlwaysStoppedAnimation(
                                AppColors.muted.withValues(alpha: 0.45),
                              ),
                            )
                          : TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: progress),
                              duration: const Duration(milliseconds: 650),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, _) =>
                                  CircularProgressIndicator(
                                    value: value,
                                    strokeWidth: 9,
                                    strokeCap: StrokeCap.round,
                                    backgroundColor: const Color(0xFF2A303B),
                                    valueColor: const AlwaysStoppedAnimation(
                                      AppColors.blue,
                                    ),
                                  ),
                            ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${count ?? '—'}/${habits.length}',
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        Text(
                          count == null ? 'date unavailable' : 'done today',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
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
                      value: count?.toString() ?? '—',
                    ),
                    const SizedBox(height: 10),
                    _ProgressBreakdownLine(
                      icon: Icons.hourglass_bottom_rounded,
                      color: AppColors.orange,
                      label: 'Pending',
                      value: count == null
                          ? '—'
                          : '${habits.length - count}',
                    ),
                    const SizedBox(height: 13),
                    if (progress != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: const Color(0xFF2A303B),
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.violet,
                          ),
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

  Widget _buildPlayerCard() {
    final progress = gamification;
    if (progress == null) {
      return GlassCard(
        child: Row(
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.violet,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Player progress is unavailable. Habit tracking is still working.',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
    return GlassCard(
      glow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.violet.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.violet,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level ${progress.level}',
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${progress.totalXp} total XP',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if ((recentXpEarned ?? 0) > 0)
                TweenAnimationBuilder<double>(
                  key: ValueKey(recentXpEarned),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 550),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) => Opacity(
                    opacity: value.clamp(0, 1),
                    child: Transform.translate(
                      offset: Offset(0, (1 - value) * 8),
                      child: child,
                    ),
                  ),
                  child: Text(
                    '+$recentXpEarned XP',
                    style: const TextStyle(
                      color: AppColors.green,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress.levelProgress),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: const Color(0xFF2A303B),
                valueColor: const AlwaysStoppedAnimation(AppColors.violet),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${progress.xpIntoLevel} / 100 XP · ${progress.xpToNextLevel} XP to level ${progress.level + 1}',
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyQuests() {
    final progress = gamification;
    final count = progress?.completedToday;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionHeading(title: 'Daily quests')),
              TextButton(
                onPressed: progress == null
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AchievementsScreen(
                            progress: progress,
                          ),
                        ),
                      ),
                child: const Text('Achievements'),
              ),
            ],
          ),
          if (count == null) ...[
            const SizedBox(height: 8),
            const Text(
              'Quest progress is unavailable without an account-local date.',
              style: TextStyle(color: AppColors.muted, fontSize: 10),
            ),
          ],
          for (final quest in DailyQuestDefinition.all) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  count == null
                      ? Icons.help_outline_rounded
                      : count >= quest.target
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: count != null && count >= quest.target
                      ? AppColors.green
                      : count == null
                      ? AppColors.orange
                      : AppColors.faint,
                  size: 19,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quest.title,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      if (count != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: (count / quest.target).clamp(0, 1),
                            minHeight: 5,
                            backgroundColor: const Color(0xFF2A303B),
                            valueColor: const AlwaysStoppedAnimation(
                              AppColors.blue,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${count?.toString() ?? '—'}/${quest.target} · +${quest.rewardXp} XP',
                  style: const TextStyle(color: AppColors.muted, fontSize: 10),
                ),
              ],
            ),
          ],
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
            label: 'Current streak',
            value: '—',
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
      trailing: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const StatisticsScreen()),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Stats',
                  style: TextStyle(
                    color: AppColors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.blue,
                  size: 15,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHabitItem(Habit habit) {
    final today = _accountDateSource?.today();
    return HabitCard(
      habit: habit,
      dateStatusUnavailable: today == null,
      accountLocalDate: today?.utcDate,
      isCompleted: today == null ? null : habit.lastCompletedDate == today.key,
      onComplete:
          _completionTimeZoneReady && !_completingHabitIds.contains(habit.id)
          ? () => completeHabit(habit)
          : null,
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
            child: const Icon(
              Icons.flag_rounded,
              size: 30,
              color: AppColors.violet,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'No habits yet',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Build a routine that moves you forward. Add your first habit to begin your journey.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitsLoadFailure() => GlassCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      children: [
        const Text(
          'Habits could not be loaded.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: loadHabits,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ],
    ),
  );
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
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBreakdownLine extends StatelessWidget {
  const _ProgressBreakdownLine({
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
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
