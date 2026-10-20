import 'package:flutter_test/flutter_test.dart';
import 'package:habit__quest/models/account_date.dart';
import 'package:habit__quest/models/habit_completion.dart';

void main() {
  CompletionTimeZoneSettings settings(String zone) =>
      CompletionTimeZoneSettings(
        timeZone: zone,
        updatedAt: DateTime.utc(2026, 1, 1),
        nextChangeAt: DateTime.utc(2026, 1, 31),
      );

  test('account date differs from UTC and supports positive and negative offsets', () {
    final instant = DateTime.utc(2026, 1, 1, 0, 30);
    final singapore = AccountDateSource.fromSettings(settings('Asia/Singapore'));
    final losAngeles = AccountDateSource.fromSettings(
      settings('America/Los_Angeles'),
    );

    expect(singapore.dateAt(instant).key, '2026-01-01');
    expect(losAngeles.dateAt(instant).key, '2025-12-31');
  });

  test('IANA daylight-saving transition skips the nonexistent local hour', () {
    final source = AccountDateSource.fromSettings(
      settings('America/Los_Angeles'),
    );

    final before = source.at(DateTime.utc(2026, 3, 8, 9, 59));
    final after = source.at(DateTime.utc(2026, 3, 8, 10));
    expect((before.hour, before.minute, before.timeZoneOffset),
        (1, 59, const Duration(hours: -8)));
    expect((after.hour, after.minute, after.timeZoneOffset),
        (3, 0, const Duration(hours: -7)));
  });

  test('calendar date arithmetic crosses month and year without timezone shifts', () {
    final source = AccountDateSource.fromSettings(settings('Asia/Singapore'));
    final newYear = source.dateAt(DateTime.utc(2026, 12, 31, 16, 30));

    expect(newYear.key, '2027-01-01');
    expect(newYear.addDays(-1).key, '2026-12-31');
    expect(AccountCalendarDate.parse('2026-12-31').firstOfNextMonth.key,
        '2027-01-01');
  });

  test('date-only parsing keeps its calendar fields and rejects invalid dates', () {
    final date = AccountCalendarDate.parse('2026-01-01');
    expect(date.key, '2026-01-01');
    expect(date.utcDate, DateTime.utc(2026, 1, 1));
    expect(
      () => AccountCalendarDate.parse('2026-02-30'),
      throwsFormatException,
    );
    expect(
      () => AccountCalendarDate.parse('2026-01-01T00:00:00Z'),
      throwsFormatException,
    );
  });

  test('missing and invalid timezone settings are not treated as device time', () {
    expect(CompletionTimeZoneSettings.fromRpc(null), isNull);
    expect(AccountDateSource.isValidTimeZone('Nope/Not_A_Zone'), isFalse);
    expect(
      () => AccountDateSource.fromSettings(settings('Nope/Not_A_Zone')),
      throwsFormatException,
    );
    expect(
      () => CompletionTimeZoneSettings.fromRpc({
        'time_zone': 'UTC',
        'updated_at': '2026-01-01T00:00:00Z',
      }),
      throwsFormatException,
    );
  });

  test('updated timezone settings create a source with the new date boundary', () {
    final instant = DateTime.utc(2026, 1, 1, 16);
    final oldSource = AccountDateSource.fromSettings(settings('UTC'));
    final newSource = AccountDateSource.fromSettings(settings('Asia/Tokyo'));

    expect(oldSource.dateAt(instant).key, '2026-01-01');
    expect(newSource.dateAt(instant).key, '2026-01-02');
    expect(newSource.at(instant).hour, 1);
    expect(newSource.settings.timeZone, 'Asia/Tokyo');
  });

  test('recorded server date remains unchanged when parsed', () {
    final completion = HabitCompletion.fromMap({
      'habit_id': 'habit-1',
      'completed_on': '2026-01-01',
    });

    expect(completion.completedOn, '2026-01-01');
  });
}
