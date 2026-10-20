import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class CompletionTimeZoneSettings {
  const CompletionTimeZoneSettings({
    required this.timeZone,
    required this.updatedAt,
    required this.nextChangeAt,
  });

  final String timeZone;
  final DateTime updatedAt;
  final DateTime nextChangeAt;

  static CompletionTimeZoneSettings? fromRpc(Object? value) {
    if (value == null) return null;
    if (value is! Map ||
        value['time_zone'] is! String ||
        value['updated_at'] is! String ||
        value['next_change_at'] is! String) {
      throw const FormatException('Invalid timezone settings response.');
    }
    final zone = (value['time_zone'] as String).trim();
    if (zone != value['time_zone'] || !AccountDateSource.isValidTimeZone(zone)) {
      throw const FormatException('Invalid timezone settings response.');
    }
    final updatedAt = _parseTimestamp(value['updated_at'] as String);
    final nextChangeAt = _parseTimestamp(value['next_change_at'] as String);
    if (updatedAt == null ||
        nextChangeAt == null ||
        nextChangeAt.isBefore(updatedAt)) {
      throw const FormatException('Invalid timezone settings response.');
    }
    return CompletionTimeZoneSettings(
      timeZone: zone,
      updatedAt: updatedAt,
      nextChangeAt: nextChangeAt,
    );
  }
}

DateTime? _parseTimestamp(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}T.+(?:Z|[+-]\d{2}:?\d{2})$').hasMatch(value)) {
    return null;
  }
  return DateTime.tryParse(value)?.toUtc();
}

/// A date without a timezone or time-of-day. Its DateTime representation is
/// UTC-backed only to provide stable calendar arithmetic; its fields are the
/// account-local calendar date and are never converted as an instant.
class AccountCalendarDate implements Comparable<AccountCalendarDate> {
  const AccountCalendarDate(this.year, this.month, this.day);

  factory AccountCalendarDate.fromDateTime(DateTime date) =>
      AccountCalendarDate(date.year, date.month, date.day);

  factory AccountCalendarDate.parse(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw const FormatException('Invalid calendar date.');
    }
    final parts = value.split('-').map(int.parse).toList();
    final date = DateTime.utc(parts[0], parts[1], parts[2]);
    final parsed = AccountCalendarDate.fromDateTime(date);
    if (parsed.key != value) throw const FormatException('Invalid calendar date.');
    return parsed;
  }

  final int year;
  final int month;
  final int day;

  String get key =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  DateTime get utcDate => DateTime.utc(year, month, day);
  int get daysInMonth => DateTime.utc(year, month + 1, 0).day;
  AccountCalendarDate get firstOfMonth => AccountCalendarDate(year, month, 1);
  AccountCalendarDate get firstOfNextMonth => month == 12
      ? AccountCalendarDate(year + 1, 1, 1)
      : AccountCalendarDate(year, month + 1, 1);

  AccountCalendarDate addDays(int count) =>
      AccountCalendarDate.fromDateTime(utcDate.add(Duration(days: count)));

  @override
  int compareTo(AccountCalendarDate other) => utcDate.compareTo(other.utcDate);

  bool isBefore(AccountCalendarDate other) => compareTo(other) < 0;
  bool isAfter(AccountCalendarDate other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is AccountCalendarDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

class AccountDateSource {
  AccountDateSource({
    required this.settings,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       _location = _locationFor(settings.timeZone);

  final CompletionTimeZoneSettings settings;
  final DateTime Function() _clock;
  final timezone.Location _location;

  static bool _databaseReady = false;

  static bool isValidTimeZone(String value) {
    if (value.isEmpty ||
        value.length > 100 ||
        value != value.trim() ||
        value.startsWith('posix/') ||
        value.startsWith('right/')) {
      return false;
    }
    if (value != 'UTC' &&
        (!value.contains('/') || value.split('/').any((part) => part.isEmpty))) {
      return false;
    }
    try {
      _ensureDatabase();
      timezone.getLocation(value);
      return true;
    } on ArgumentError {
      return false;
    } catch (_) {
      return false;
    }
  }

  static timezone.Location _locationFor(String value) {
    _ensureDatabase();
    try {
      return timezone.getLocation(value);
    } on ArgumentError {
      throw const FormatException('Unknown IANA timezone.');
    }
  }

  static void _ensureDatabase() {
    if (_databaseReady) return;
    timezone_data.initializeTimeZones();
    _databaseReady = true;
  }

  factory AccountDateSource.fromSettings(
    CompletionTimeZoneSettings settings, {
    DateTime Function()? clock,
  }) {
    if (!isValidTimeZone(settings.timeZone)) {
      throw const FormatException('Unknown IANA timezone.');
    }
    return AccountDateSource(settings: settings, clock: clock);
  }

  timezone.TZDateTime at(DateTime instant) =>
      timezone.TZDateTime.from(instant.toUtc(), _location);

  AccountCalendarDate dateAt(DateTime instant) =>
      AccountCalendarDate.fromDateTime(at(instant));

  AccountCalendarDate today() => dateAt(_clock());
}
