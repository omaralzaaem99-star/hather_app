import 'package:hather_app/core/utils/phone_number_formatter.dart';

/// App-wide display formatting for dates/times.
///
/// Rules:
/// - 12-hour clock with Arabic ص / م
/// - English digits 0-9 only
/// - Display only — does not change stored timestamps
class AppDateTimeFormat {
  const AppDateTimeFormat._();

  /// `2026/08/26 - 4:49 م`
  static String dateTime(DateTime value) {
    final local = value.toLocal();
    return '${_date(local)} - ${_time(local)}';
  }

  /// `4:49 م`
  static String time(DateTime value) => _time(value.toLocal());

  /// Relative labels for recent times; falls back to [dateTime] after ~7 days.
  static String relative(DateTime when, {DateTime? now}) {
    final local = when.toLocal();
    final current = (now ?? DateTime.now()).toLocal();
    final diff = current.difference(local);

    if (diff.inSeconds < 45) return 'الآن';
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes.clamp(1, 59);
      return 'منذ $m ${_pluralMinutes(m)}';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours.clamp(1, 23);
      return 'منذ $h ${_pluralHours(h)}';
    }
    if (diff.inDays < 7) {
      final d = diff.inDays.clamp(1, 6);
      return 'منذ $d ${_pluralDays(d)}';
    }

    return dateTime(local);
  }

  static String _date(DateTime local) {
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return PhoneNumberFormatter.toEnglishDigits('$y/$m/$d');
  }

  static String _time(DateTime local) {
    var hours = local.hour;
    final minutes = local.minute.toString().padLeft(2, '0');
    final period = hours >= 12 ? 'م' : 'ص';
    hours %= 12;
    if (hours == 0) hours = 12;
    return PhoneNumberFormatter.toEnglishDigits('$hours:$minutes $period');
  }

  static String _pluralMinutes(int n) => n == 1 ? 'دقيقة' : 'دقائق';
  static String _pluralHours(int n) => n == 1 ? 'ساعة' : 'ساعات';
  static String _pluralDays(int n) => n == 1 ? 'يوم' : 'أيام';
}
