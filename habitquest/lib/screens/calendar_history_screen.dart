import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../models/account_date.dart';
import '../models/habit_completion.dart';
import '../models/request_generation.dart';
import '../services/habit_service.dart';
import '../services/habit_repository.dart';
import '../widgets/premium_ui.dart';

class CalendarHistoryScreen extends StatefulWidget {
  const CalendarHistoryScreen({super.key, this.repository, this.accountClock});

  final HabitBrowserRepository? repository;
  final DateTime Function()? accountClock;

  @override
  State<CalendarHistoryScreen> createState() => _CalendarHistoryScreenState();
}

class _CalendarHistoryScreenState extends State<CalendarHistoryScreen> {
  late final HabitBrowserRepository habitService =
      widget.repository ?? HabitService();
  List<Habit> habits = [];
  List<HabitCompletion> completions = [];
  bool isLoading = true;
  bool loadFailed = false;
  DateTime? displayedMonth;
  DateTime? selectedDate;
  AccountDateSource? _accountDateSource;
  AccountCalendarDate? _accountToday;
  final _loadGeneration = RequestGeneration();
  bool _initialDateSelected = false;

  static const monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

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
      final today = dateSource?.today();
      final firstCompletion = loaded.completions
          .map((completion) {
            try {
              return completion.calendarDate?.utcDate;
            } on FormatException {
              return null;
            }
          })
          .whereType<DateTime>()
          .fold<DateTime?>(null, (earliest, date) {
            if (earliest == null || date.isBefore(earliest)) return date;
            return earliest;
          });
      final initialDate = today?.utcDate ?? firstCompletion;
      final previousSettings = _accountDateSource?.settings;
      final zoneChanged = previousSettings?.timeZone != dateSource?.settings.timeZone ||
          previousSettings?.updatedAt != dateSource?.settings.updatedAt;
      setState(() {
        habits = loaded.habits;
        completions = deduplicateHabitCompletions(loaded.completions);
        _accountDateSource = dateSource;
        _accountToday = today;
        if ((!_initialDateSelected || (today != null && zoneChanged)) &&
            initialDate != null) {
          selectedDate = initialDate;
          displayedMonth = DateTime.utc(initialDate.year, initialDate.month);
          _initialDateSelected = true;
        } else if (today == null && firstCompletion == null) {
          selectedDate = null;
          displayedMonth = null;
          _initialDateSelected = false;
        }
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
        const SnackBar(content: Text('Failed to load habit history.')),
      );
    }
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _monthLabel(DateTime date) =>
      '${monthNames[date.month - 1]} ${date.year}';

  String _dayLabel(DateTime date) =>
      '${monthNames[date.month - 1]} ${date.day}, ${date.year}';

  Map<String, int> _completionCounts() {
    final counts = <String, int>{};
    for (final completion in completions) {
      final key = completion.calendarDate?.key;
      if (key == null) continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  List<Habit> _habitsForSelectedDate(DateTime date) {
    final key = _dateKey(date);
    final completedHabitIds = completions
        .where((completion) => completion.calendarDate?.key == key)
        .map((completion) => completion.habitId)
        .toSet();
    return habits
        .where((habit) => completedHabitIds.contains(habit.id))
        .toList();
  }

  void _changeMonth(int amount) {
    final currentMonth = displayedMonth;
    final currentDate = selectedDate;
    if (currentMonth == null || currentDate == null) return;
    final nextMonth = DateTime.utc(
      currentMonth.year,
      currentMonth.month + amount,
      1,
    );
    final lastDay = DateTime.utc(nextMonth.year, nextMonth.month + 1, 0).day;
    final day = math.min(currentDate.day, lastDay);
    setState(() {
      displayedMonth = nextMonth;
      selectedDate = DateTime.utc(nextMonth.year, nextMonth.month, day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final month = displayedMonth;
    final selection = selectedDate;
    final completionCounts = _completionCounts();
    final selectedHabits = selection == null
        ? const <Habit>[]
        : _habitsForSelectedDate(selection);
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
                        'Completion history could not be loaded.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      TextButton(
                        onPressed: loadHabits,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : month == null || selection == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Calendar date is unavailable. Set a valid account timezone in Profile or load recorded completion history.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted),
                        ),
                        TextButton(onPressed: loadHabits, child: const Text('Retry')),
                      ],
                    ),
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
                        'YOUR HISTORY',
                        style: TextStyle(
                          color: AppColors.blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Calendar',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'A view of the completion dates recorded for your habits.',
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                      const SizedBox(height: 19),
                      GlassCard(
                        glow: true,
                        padding: const EdgeInsets.fromLTRB(15, 13, 15, 16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  tooltip: 'Previous month',
                                  onPressed: () => _changeMonth(-1),
                                  icon: const Icon(
                                    Icons.chevron_left_rounded,
                                    color: AppColors.text,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    _monthLabel(month),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppColors.text,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Next month',
                                  onPressed: () => _changeMonth(1),
                                  icon: const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.text,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: weekdays
                                  .map(
                                    (day) => Expanded(
                                      child: Center(
                                        child: Text(
                                          day,
                                          style: const TextStyle(
                                            color: AppColors.faint,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                            const SizedBox(height: 10),
                            _buildMonthGrid(completionCounts, month, selection),
                            const SizedBox(height: 12),
                            const Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  color: AppColors.blue,
                                  size: 8,
                                ),
                                SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    'Recorded completion',
                                    style: TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 23),
                      SectionHeading(
                        title: _dayLabel(selection),
                        trailing: Text(
                          '${selectedHabits.length} ${selectedHabits.length == 1 ? 'habit' : 'habits'}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (selectedHabits.isEmpty)
                        GlassCard(
                          padding: const EdgeInsets.all(19),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.blue,
                                size: 20,
                              ),
                              SizedBox(width: 11),
                              Expanded(
                                child: Text(
                                  'No completion record exists for this date.',
                                  style: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        GlassCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 5,
                          ),
                          child: Column(
                            children: selectedHabits
                                .map((habit) => _CompletionRow(habit: habit))
                                .toList(),
                          ),
                        ),
                      const SizedBox(height: 13),
                      const Text(
                        'Only recorded completion dates are shown. Earlier completion history was not reconstructed.',
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

  Widget _buildMonthGrid(
    Map<String, int> counts,
    DateTime displayedMonth,
    DateTime selectedDate,
  ) {
    final firstDay = DateTime.utc(displayedMonth.year, displayedMonth.month, 1);
    final leadingEmptyDays = firstDay.weekday - 1;
    final daysInMonth = DateTime.utc(
      displayedMonth.year,
      displayedMonth.month + 1,
      0,
    ).day;
    final cellCount = leadingEmptyDays + daysInMonth;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 5,
        crossAxisSpacing: 4,
        childAspectRatio: 0.95,
      ),
      itemCount: cellCount,
      itemBuilder: (context, index) {
        if (index < leadingEmptyDays) return const SizedBox.shrink();
        final day = index - leadingEmptyDays + 1;
        final date = DateTime.utc(displayedMonth.year, displayedMonth.month, day);
        final key = _dateKey(date);
        final count = counts[key] ?? 0;
        final selected = _dateKey(date) == _dateKey(selectedDate);
        final today = _accountToday == AccountCalendarDate.fromDateTime(date);
        return Tooltip(
          message: count == 0
              ? _dayLabel(date)
              : '$count completion${count == 1 ? '' : 's'} recorded',
          child: Semantics(
            button: true,
            selected: selected,
            label: _dayLabel(date),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => setState(() => selectedDate = date),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: selected
                      ? const LinearGradient(
                          colors: [AppColors.blue, AppColors.violet],
                        )
                      : null,
                  color: selected
                      ? null
                      : (today ? const Color(0x302F75A8) : Colors.transparent),
                  border: Border.all(
                    color: today && !selected
                        ? AppColors.blue.withValues(alpha: 0.4)
                        : Colors.transparent,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        '$day',
                        style: TextStyle(
                          color: selected ? Colors.white : AppColors.text,
                          fontSize: 12,
                          fontWeight: selected || today
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (count > 0)
                      Positioned(
                        bottom: 4,
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: selected ? Colors.white : AppColors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CompletionRow extends StatelessWidget {
  const _CompletionRow({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final color = habitCategoryColor(habit.category);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              habitCategoryIcon(habit.category),
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${habit.category} · ${habit.frequency}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.green,
            size: 21,
          ),
        ],
      ),
    );
  }
}
