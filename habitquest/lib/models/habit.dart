import 'account_date.dart';

class Habit {
  static const supportedCategories = <String>[
    'Study',
    'Health',
    'Fitness',
    'Personal',
    'Other',
  ];

  static const supportedFrequencies = <String>[
    'Daily',
    'Weekly',
    'Every day',
    'Weekdays',
    'Weekends',
    'Once a week',
    'Twice a week',
    'Once a month',
  ];
  final String id;
  final String userId;
  final String name;
  final String category;
  final String frequency;
  final int streak;
  final String? lastCompletedDate;
  final DateTime? createdAt;

  Habit({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.frequency,
    required this.streak,
    this.lastCompletedDate,
    this.createdAt,
  });

  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'].toString(),
      userId: map['user_id'].toString(),
      name: map['name'] ?? '',
      category: map['category'] ?? 'Other',
      frequency: map['frequency'] ?? 'Daily',
      streak: map['streak'] ?? 0,
      lastCompletedDate: map['last_completed_date'],
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'category': category,
      'frequency': frequency,
      'streak': streak,
      'last_completed_date': lastCompletedDate,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  int get currentStreak => currentStreakOn(DateTime.now());

  /// Returns the stored streak while its schedule has not been missed.
  ///
  /// Twice-weekly streaks use the supplied completion history; other schedules
  /// continue to use the persisted summary and latest completion date.
  int currentStreakOn(DateTime date, {Iterable<DateTime>? completionHistory}) {
    return currentStreakWithHistory(date, completionHistory: completionHistory) ??
        0;
  }

  /// Returns null when a twice-weekly streak cannot be calculated because
  /// recorded completion history was not supplied.
  int? currentStreakWithHistory(
    DateTime date, {
    Iterable<DateTime>? completionHistory,
  }) {
    if (_normalizedFrequency == 'Twice a week') {
      if (completionHistory == null) return null;
      return _twiceWeeklyStreak(date, completionHistory);
    }
    return _currentStreakFromSummary(date);
  }

  int _currentStreakFromSummary(DateTime date) {
    final lastCompleted = _lastCompletedDay;
    if (lastCompleted == null) return 0;

    final today = _dateOnly(date);
    if (today.isBefore(lastCompleted)) return 0;

    switch (_normalizedFrequency) {
      case 'Every day':
      case 'Weekdays':
      case 'Weekends':
        return _scheduledDaysBetween(lastCompleted, today) == 0 ? streak : 0;
      case 'Once a week':
        final weeksSinceCompletion = _weeksBetween(lastCompleted, today);
        return weeksSinceCompletion <= 1 ? streak : 0;
      case 'Twice a week':
        return _weeksBetween(lastCompleted, today) <= 1 ? streak : 0;
      case 'Once a month':
        final monthsSinceCompletion = _monthsBetween(lastCompleted, today);
        return monthsSinceCompletion <= 1 ? streak : 0;
      default:
        return 0;
    }
  }

  int _twiceWeeklyStreak(DateTime today, Iterable<DateTime> history) {
    final completionsByWeek = <int, Set<int>>{};
    for (final completion in history.map(_dateOnly)) {
      if (completion.isAfter(_dateOnly(today))) continue;
      final week = _weekStart(completion).millisecondsSinceEpoch;
      completionsByWeek.putIfAbsent(week, () => <int>{}).add(
        completion.millisecondsSinceEpoch,
      );
    }
    final successfulWeeks = completionsByWeek.entries
        .where((entry) => entry.value.length >= 2)
        .map((entry) => entry.key)
        .toSet();
    if (successfulWeeks.isEmpty) return 0;
    var currentWeek = _weekStart(today);
    if (!successfulWeeks.contains(currentWeek.millisecondsSinceEpoch)) {
      currentWeek = currentWeek.subtract(const Duration(days: 7));
    }
    var count = 0;
    while (successfulWeeks.contains(currentWeek.millisecondsSinceEpoch)) {
      count++;
      currentWeek = currentWeek.subtract(const Duration(days: 7));
    }
    return count;
  }

  DateTime _weekStart(DateTime date) =>
      _dateOnly(date).subtract(Duration(days: date.weekday - DateTime.monday));

  /// Applies today's completion to the stored count without inventing history.
  int streakAfterCompletionOn(DateTime date) {
    final lastCompleted = _lastCompletedDay;
    final completionDay = _dateOnly(date);
    if (lastCompleted == completionDay) return streak;

    if (lastCompleted == null) {
      // An initial off-day completion starts history without creating a
      // streak; the first scheduled completion becomes streak one.
      return _isScheduledDay(completionDay) ? 1 : 0;
    }

    if (completionDay.isBefore(lastCompleted)) return 1;

    switch (_normalizedFrequency) {
      case 'Every day':
        return completionDay.difference(lastCompleted).inDays == 1
            ? streak + 1
            : 1;
      case 'Weekdays':
      case 'Weekends':
        if (!_isScheduledDay(completionDay))
          return currentStreakOn(completionDay);
        return _scheduledDaysBetween(lastCompleted, completionDay) == 0
            ? streak + 1
            : 1;
      case 'Once a week':
        final weeksBetween = _weeksBetween(lastCompleted, completionDay);
        if (weeksBetween == 0) return streak;
        return weeksBetween == 1 ? streak + 1 : 1;
      case 'Twice a week':
        // The completion-history based calculation is used by history-aware
        // screens; retain the current period summary for completion writes.
        final weeksBetween = _weeksBetween(lastCompleted, completionDay);
        if (weeksBetween == 0) return streak;
        return weeksBetween == 1 ? streak + 1 : 1;
      case 'Once a month':
        final monthsBetween = _monthsBetween(lastCompleted, completionDay);
        if (monthsBetween == 0) return streak;
        return monthsBetween == 1 ? streak + 1 : 1;
      default:
        return 1;
    }
  }

  int streakAfterCompletionWithHistory(
    DateTime date, {
    required Iterable<DateTime> completionHistory,
  }) {
    if (_normalizedFrequency != 'Twice a week') {
      return streakAfterCompletionOn(date);
    }
    return _twiceWeeklyStreak(date, completionHistory);
  }

  bool wasCompletedOn(DateTime date) => _lastCompletedDay == _dateOnly(date);

  DateTime? get _lastCompletedDay {
    final parsed = lastCompletedDate;
    if (parsed == null) return null;
    try {
      return AccountCalendarDate.parse(parsed).utcDate;
    } on FormatException {
      return null;
    }
  }

  String get _normalizedFrequency => switch (frequency) {
    'Daily' => 'Every day',
    'Weekly' => 'Once a week',
    'Every day' ||
    'Weekdays' ||
    'Weekends' ||
    'Once a week' ||
    'Twice a week' ||
    'Once a month' => frequency,
    _ => 'Every day',
  };

  bool _isScheduledDay(DateTime date) {
    switch (_normalizedFrequency) {
      case 'Weekdays':
        return date.weekday >= DateTime.monday &&
            date.weekday <= DateTime.friday;
      case 'Weekends':
        return date.weekday == DateTime.saturday ||
            date.weekday == DateTime.sunday;
      case 'Every day':
        return true;
      default:
        return false;
    }
  }

  int _scheduledDaysBetween(DateTime start, DateTime end) {
    if (!end.isAfter(start)) return 0;

    var scheduledDays = 0;
    for (
      var day = start.add(const Duration(days: 1));
      day.isBefore(end);
      day = day.add(const Duration(days: 1))
    ) {
      if (_isScheduledDay(day)) scheduledDays++;
    }
    return scheduledDays;
  }

  int _weeksBetween(DateTime start, DateTime end) {
    final startWeek = start.subtract(Duration(days: start.weekday - 1));
    final endWeek = end.subtract(Duration(days: end.weekday - 1));
    return endWeek.difference(startWeek).inDays ~/ 7;
  }

  int _monthsBetween(DateTime start, DateTime end) =>
      (end.year - start.year) * 12 + end.month - start.month;

  DateTime _dateOnly(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);
}
