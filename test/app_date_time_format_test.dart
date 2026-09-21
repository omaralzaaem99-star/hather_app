import 'package:flutter_test/flutter_test.dart';
import 'package:hather_app/core/utils/app_date_time_format.dart';

void main() {
  test('dateTime uses 12-hour format with Arabic meridiem', () {
    // Construct local wall-clock via DateTime constructor (local).
    final afternoon = DateTime(2026, 8, 26, 16, 49);
    final morning = DateTime(2026, 8, 26, 9, 15);
    final noon = DateTime(2026, 8, 26, 12, 0);
    final midnight = DateTime(2026, 8, 26, 0, 5);

    expect(AppDateTimeFormat.dateTime(afternoon), '2026/08/26 - 4:49 م');
    expect(AppDateTimeFormat.dateTime(morning), '2026/08/26 - 9:15 ص');
    expect(AppDateTimeFormat.dateTime(noon), '2026/08/26 - 12:00 م');
    expect(AppDateTimeFormat.dateTime(midnight), '2026/08/26 - 12:05 ص');
  });

  test('time-only never uses 24-hour digits', () {
    final evening = DateTime(2026, 8, 26, 21, 30);
    final label = AppDateTimeFormat.time(evening);
    expect(label, '9:30 م');
    expect(label.contains('21'), isFalse);
    expect(RegExp(r'[٠-٩]').hasMatch(label), isFalse);
  });

  test('relative falls back to absolute dateTime', () {
    final old = DateTime.now().subtract(const Duration(days: 10));
    final label = AppDateTimeFormat.relative(old);
    expect(label.contains('ص') || label.contains('م'), isTrue);
    expect(label.contains('-'), isTrue);
  });
}
