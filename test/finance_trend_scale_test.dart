import 'package:flutter_test/flutter_test.dart';
import 'package:my_device/features/devices/views/device_finance_overview_page.dart';

/// Purpose: Test the finance trend chart's calendar-day arithmetic.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: `Duration(days: n)` is 24-hour blocks, so adding it to a local
/// midnight lands on 23:00 or 01:00 after a daylight-saving change. These
/// tests pin the calendar-day behaviour; they only prove the DST case when
/// the suite runs in a DST zone (CI: `TZ=America/New_York`), and are plain
/// calendar checks elsewhere.
void main() {
  test('calendarDaysBetween counts calendar days across a DST change', () {
    // 2026-03-08 and 2026-11-01 are the US switch days; a local-time
    // Duration.inDays would report one day too few over the spring gap.
    expect(
      calendarDaysBetween(DateTime(2026, 3, 1), DateTime(2026, 3, 31)),
      30,
    );
    expect(
      calendarDaysBetween(DateTime(2026, 10, 25), DateTime(2026, 11, 5)),
      11,
    );
    expect(calendarDaysBetween(DateTime(2026, 5, 5), DateTime(2026, 5, 5)), 0);
    expect(calendarDaysBetween(DateTime(2026, 5, 6), DateTime(2026, 5, 5)), -1);
  });

  test('every trend point is a local midnight, also across DST', () {
    final today = DateTime(2026, 3, 20);
    final dates = trendScaleDates(
      DateTime(2026, 3, 1),
      today,
      DateTime(2026, 4, 10),
    );
    expect(dates.first, DateTime(2026, 3, 1));
    expect(dates.last, DateTime(2026, 4, 10));
    expect(dates, contains(today));
    for (final d in dates) {
      expect(d, DateTime(d.year, d.month, d.day), reason: '$d is not midnight');
    }
    expect(dates.toSet(), hasLength(dates.length));
    // Daily steps for a short range.
    expect(dates, hasLength(41));
  });

  test('long ranges step weekly then monthly and stay sorted', () {
    final weekly = trendScaleDates(
      DateTime(2024, 1, 1),
      DateTime(2025, 1, 1),
      DateTime(2026, 1, 1),
    );
    expect(weekly.length, lessThan(120));
    expect([...weekly]..sort(), weekly);
    final monthly = trendScaleDates(
      DateTime(2015, 1, 1),
      DateTime(2026, 1, 1),
      DateTime(2037, 1, 1),
    );
    expect(monthly.length, lessThan(300));
    for (final d in monthly) {
      expect(d, DateTime(d.year, d.month, d.day));
    }
  });
}
