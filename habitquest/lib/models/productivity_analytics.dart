import 'habit.dart';
import 'habit_completion.dart';
import 'account_date.dart';

class ProductivityPeriodSummary {
  const ProductivityPeriodSummary({
    required this.recordedCompletions,
    required this.expectedCompletions,
    required this.successfulOpportunities,
    required this.dailyCompletions,
  });

  final int recordedCompletions;
  final int expectedCompletions;
  final int successfulOpportunities;
  final List<int> dailyCompletions;

  double get completionRate => expectedCompletions == 0
      ? 0
      : (successfulOpportunities / expectedCompletions)
            .clamp(0.0, 1.0)
            .toDouble();

  factory ProductivityPeriodSummary.calculate({
    required Iterable<Habit> habits,
    required Iterable<HabitCompletion> completions,
    required DateTime start,
    required DateTime end,
    required AccountDateSource dateSource,
  }) {
    final first = _dateOnly(start);
    final last = _dateOnly(end);
    if (last.isBefore(first)) {
      return const ProductivityPeriodSummary(
        recordedCompletions: 0,
        expectedCompletions: 0,
        successfulOpportunities: 0,
        dailyCompletions: [],
      );
    }
    final days = last.difference(first).inDays + 1;
    final daily = List<int>.filled(days, 0);
    final byHabitDay = <String, Set<String>>{};
    final habitById = {for (final habit in habits) habit.id: habit};

    for (final completion in completions) {
      final date = completion.calendarDate?.utcDate;
      if (date == null) continue;
      final day = _dateOnly(date);
      if (day.isBefore(first) || day.isAfter(last)) continue;
      final index = day.difference(first).inDays;
      daily[index]++;
      byHabitDay
          .putIfAbsent(completion.habitId, () => <String>{})
          .add(_dateKey(day));
    }

    var expected = 0;
    var countForRate = 0;
    for (final habit in habitById.values) {
      final created = habit.createdAt == null
          ? first
          : dateSource.dateAt(habit.createdAt!).utcDate;
      final activeStart = created.isAfter(first) ? created : first;
      if (activeStart.isAfter(last)) continue;
      final completedDays = byHabitDay[habit.id] ?? const <String>{};
      final frequency = switch (habit.frequency) {
        'Daily' => 'Every day',
        'Weekly' => 'Once a week',
        _ => habit.frequency,
      };

      if (frequency == 'Once a week' || frequency == 'Twice a week') {
        final weeks = _periodBuckets(activeStart, last, weekly: true);
        final target = frequency == 'Once a week' ? 1 : 2;
        expected += weeks.length * target;
        for (final week in weeks) {
          final daysInWeek = completedDays
              .map((key) => AccountCalendarDate.parse(key).utcDate)
              .where((date) => _weekStart(date) == week)
              .length;
          countForRate += daysInWeek.clamp(0, target).toInt();
        }
      } else if (frequency == 'Once a month') {
        final months = _periodBuckets(activeStart, last, weekly: false);
        expected += months.length;
        for (final month in months) {
          final hits = completedDays
              .map((key) => AccountCalendarDate.parse(key).utcDate)
              .where(
                (date) => date.year == month.year && date.month == month.month,
              )
              .length;
          countForRate += hits.clamp(0, 1).toInt();
        }
      } else {
        for (
          var day = activeStart;
          !day.isAfter(last);
          day = day.add(const Duration(days: 1))
        ) {
          if (!_isScheduled(frequency, day)) continue;
          expected++;
          if (completedDays.contains(_dateKey(day))) countForRate++;
        }
      }
    }

    return ProductivityPeriodSummary(
      recordedCompletions: daily.fold(0, (sum, value) => sum + value),
      expectedCompletions: expected,
      successfulOpportunities: countForRate,
      dailyCompletions: List.unmodifiable(daily),
    );
  }
}

bool _isScheduled(String frequency, DateTime date) => switch (frequency) {
  'Weekdays' => date.weekday <= DateTime.friday,
  'Weekends' => date.weekday >= DateTime.saturday,
  _ => true,
};

List<DateTime> _periodBuckets(
  DateTime start,
  DateTime end, {
  required bool weekly,
}) {
  final buckets = <DateTime>[];
  var cursor =
      weekly ? _weekStart(start) : DateTime.utc(start.year, start.month);
  while (!cursor.isAfter(end)) {
    buckets.add(cursor);
    cursor = weekly
        ? cursor.add(const Duration(days: 7))
        : DateTime.utc(cursor.year, cursor.month + 1);
  }
  return buckets;
}

DateTime _weekStart(DateTime date) =>
    _dateOnly(date).subtract(Duration(days: date.weekday - DateTime.monday));

DateTime _dateOnly(DateTime date) => DateTime.utc(date.year, date.month, date.day);

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
