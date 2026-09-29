import '../../../../core/utils/app_date_time_format.dart';

/// Relative / absolute notification times (delegates to [AppDateTimeFormat]).
class NotificationTimeFormat {
  const NotificationTimeFormat._();

  static String relative(DateTime when, {DateTime? now}) {
    return AppDateTimeFormat.relative(when, now: now);
  }
}
