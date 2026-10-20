import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../services/habit_service.dart';
import '../widgets/premium_ui.dart';

class CalendarHistoryScreen extends StatefulWidget {
  const CalendarHistoryScreen({super.key});

  @override
  State<CalendarHistoryScreen> createState() => _CalendarHistoryScreenState();
}

class _CalendarHistoryScreenState extends State<CalendarHistoryScreen> {
  final HabitService habitService = HabitService();
  List<Habit> habits = [];
  bool isLoading = true;
  DateTime displayedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime selectedDate = DateTime.now();

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
    selectedDate =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
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
    for (final habit in habits) {
      final value = habit.lastCompletedDate;
      if (value == null) continue;
      final parsed = DateTime.tryParse(value);
      if (parsed == null) continue;
      final key = _dateKey(parsed);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  List<Habit> _habitsForSelectedDate() {
    final key = _dateKey(selectedDate);
    return habits.where((habit) {
      final value = habit.lastCompletedDate;
      if (value == null) return false;
      final parsed = DateTime.tryParse(value);
      return parsed != null && _dateKey(parsed) == key;
    }).toList();
  }

  void _changeMonth(int amount) {
    setState(() {
      displayedMonth =
          DateTime(displayedMonth.year, displayedMonth.month + amount, 1);
      final lastDay =
          DateTime(displayedMonth.year, displayedMonth.month + 1, 0).day;
      final day = math.min(selectedDate.day, lastDay);
      selectedDate = DateTime(displayedMonth.year, displayedMonth.month, day);
    });
  }

  @override
  Widget build(BuildContext context) {
    final completionCounts = _completionCounts();
    final selectedHabits = _habitsForSelectedDate();
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
                      const Text('YOUR HISTORY',
                          style: TextStyle(
                              color: AppColors.blue,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2)),
                      const SizedBox(height: 8),
                      Text('Calendar',
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 5),
                      const Text(
                          'A view of the completion dates saved for your habits.',
                          style:
                              TextStyle(color: AppColors.muted, fontSize: 13)),
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
                                  icon: const Icon(Icons.chevron_left_rounded,
                                      color: AppColors.text),
                                ),
                                Expanded(
                                  child: Text(_monthLabel(displayedMonth),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: AppColors.text,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700)),
                                ),
                                IconButton(
                                  tooltip: 'Next month',
                                  onPressed: () => _changeMonth(1),
                                  icon: const Icon(Icons.chevron_right_rounded,
                                      color: AppColors.text),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: weekdays
                                  .map((day) => Expanded(
                                        child: Center(
                                            child: Text(day,
                                                style: const TextStyle(
                                                    color: AppColors.faint,
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.w600))),
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(height: 10),
                            _buildMonthGrid(completionCounts),
                            const SizedBox(height: 12),
                            const Row(
                              children: [
                                Icon(Icons.circle,
                                    color: AppColors.blue, size: 8),
                                SizedBox(width: 7),
                                Expanded(
                                    child: Text(
                                        'Latest saved completion for a habit',
                                        style: TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 11))),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 23),
                      SectionHeading(
                        title: _dayLabel(selectedDate),
                        trailing: Text(
                            '${selectedHabits.length} ${selectedHabits.length == 1 ? 'habit' : 'habits'}',
                            style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 12),
                      if (selectedHabits.isEmpty)
                        GlassCard(
                          padding: const EdgeInsets.all(19),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  color: AppColors.blue, size: 20),
                              SizedBox(width: 11),
                              Expanded(
                                  child: Text(
                                      'No completion is currently saved for this date.',
                                      style: TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 13,
                                          height: 1.4))),
                            ],
                          ),
                        )
                      else
                        GlassCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 5),
                          child: Column(
                            children: selectedHabits
                                .map((habit) => _CompletionRow(habit: habit))
                                .toList(),
                          ),
                        ),
                      const SizedBox(height: 13),
                      const Text(
                        'History reflects each habit’s latest saved completion date; older completion dates are not stored by this app.',
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

  Widget _buildMonthGrid(Map<String, int> counts) {
    final firstDay = DateTime(displayedMonth.year, displayedMonth.month, 1);
    final leadingEmptyDays = firstDay.weekday - 1;
    final daysInMonth =
        DateTime(displayedMonth.year, displayedMonth.month + 1, 0).day;
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
        final date = DateTime(displayedMonth.year, displayedMonth.month, day);
        final key = _dateKey(date);
        final count = counts[key] ?? 0;
        final selected = _dateKey(date) == _dateKey(selectedDate);
        final today = _dateKey(date) == _dateKey(DateTime.now());
        return Tooltip(
          message: count == 0
              ? _dayLabel(date)
              : '$count latest completion${count == 1 ? '' : 's'} saved',
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
                          colors: [AppColors.blue, AppColors.violet])
                      : null,
                  color: selected
                      ? null
                      : (today ? const Color(0x302F75A8) : Colors.transparent),
                  border: Border.all(
                      color: selected
                          ? Colors.transparent
                          : today
                              ? AppColors.blue.withValues(alpha: 0.4)
                              : Colors.transparent),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text('$day',
                          style: TextStyle(
                              color: selected ? Colors.white : AppColors.text,
                              fontSize: 12,
                              fontWeight: selected || today
                                  ? FontWeight.w700
                                  : FontWeight.w500)),
                    ),
                    if (count > 0)
                      Positioned(
                        bottom: 4,
                        child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                                color: selected ? Colors.white : AppColors.blue,
                                shape: BoxShape.circle)),
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
                borderRadius: BorderRadius.circular(12)),
            child:
                Icon(habitCategoryIcon(habit.category), color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(habit.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text('${habit.category} · ${habit.frequency}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded,
              color: AppColors.green, size: 21),
        ],
      ),
    );
  }
}
