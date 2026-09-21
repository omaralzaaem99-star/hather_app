import 'package:hather_app/core/utils/phone_number_formatter.dart';
import 'package:intl/intl.dart';

/// Display-only IQD money formatting (no DB value changes).
class IqdFormat {
  const IqdFormat._();

  static final NumberFormat _grouped = NumberFormat('#,###', 'en');

  /// Whole dinars without trailing `.0` (e.g. `15000.0` → `15,000`).
  static String format(num amount) {
    return PhoneNumberFormatter.toEnglishDigits(_grouped.format(amount.round()));
  }
}
