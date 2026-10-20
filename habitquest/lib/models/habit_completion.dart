import 'account_date.dart';

class HabitCompletion {
  final String habitId;
  final String completedOn;

  /// Parses the persisted calendar date without treating it as an instant.
  /// Returns null for malformed dates supplied by a non-server caller.
  AccountCalendarDate? get calendarDate {
    try {
      return AccountCalendarDate.parse(completedOn);
    } on FormatException {
      return null;
    }
  }

  const HabitCompletion({required this.habitId, required this.completedOn});

  factory HabitCompletion.fromMap(Map<String, dynamic> map) {
    final rawDate = map['completed_on'];
    if (rawDate is! String) {
      throw const FormatException('Invalid completion history date.');
    }
    final date = _serverDateOnly(rawDate);
    if (date == null) {
      throw const FormatException('Invalid completion history date.');
    }
    final habitId = map['habit_id'];
    if (habitId == null || habitId.toString().isEmpty) {
      throw const FormatException('Invalid completion history habit.');
    }
    return HabitCompletion(habitId: habitId.toString(), completedOn: date);
  }
}

/// Fetches zero-based inclusive pages until a short page is returned.
/// Exceptions propagate without returning a partial history snapshot.
Future<List<T>> fetchInclusivePages<T>({
  required Future<List<T>> Function(int from, int to) fetchPage,
  int pageSize = 500,
}) async {
  if (pageSize <= 0) throw ArgumentError.value(pageSize, 'pageSize');
  final rows = <T>[];
  var offset = 0;
  while (true) {
    final page = await fetchPage(offset, offset + pageSize - 1);
    rows.addAll(page);
    if (page.length < pageSize) return rows;
    offset += pageSize;
  }
}

/// Keeps the server's calendar date intact. Date-only values are never parsed
/// as local instants; timestamp values are accepted only when the server
/// timestamp contains an explicit UTC marker/offset.
String? _serverDateOnly(String value) {
  final dateOnly = RegExp(r'^(\d{4}-\d{2}-\d{2})$').firstMatch(value);
  if (dateOnly != null) {
    return _validDate(dateOnly.group(1)!);
  }

  final timestamp = RegExp(
    r'^(\d{4}-\d{2}-\d{2})T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})$',
  ).firstMatch(value);
  if (timestamp == null || DateTime.tryParse(value) == null) return null;
  return _validDate(timestamp.group(1)!);
}

String? _validDate(String value) {
  final parts = value.split('-').map(int.parse).toList();
  final parsed = DateTime.utc(parts[0], parts[1], parts[2]);
  if ('${parsed.year.toString().padLeft(4, '0')}-'
          '${parsed.month.toString().padLeft(2, '0')}-'
          '${parsed.day.toString().padLeft(2, '0')}' !=
      value) {
    return null;
  }
  return value;
}

/// Removes repeated rows while keeping the first occurrence and input order.
/// Database uniqueness should prevent these, but paged or fake repositories
/// can still repeat a row across page boundaries.
List<HabitCompletion> deduplicateHabitCompletions(
  Iterable<HabitCompletion> completions,
) {
  final seen = <String>{};
  return completions.where((completion) {
    return seen.add('${completion.habitId}\u0000${completion.completedOn}');
  }).toList();
}
