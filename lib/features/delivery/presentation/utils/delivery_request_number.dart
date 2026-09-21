import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// Public delivery order reference number helpers (English digits only).
class DeliveryRequestNumber {
  const DeliveryRequestNumber._();

  static final NumberFormat _en = NumberFormat('0', 'en');

  /// Display form: `#100001`
  static String display(int? number) {
    if (number == null || number <= 0) return '—';
    return '#${_en.format(number)}';
  }

  /// Clipboard form without hash: `100001`
  static String copyValue(int number) => _en.format(number);

  static Future<void> copyToClipboard(
    BuildContext context,
    int number,
  ) async {
    final l10n = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: copyValue(number)));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.orderNumberCopied),
        backgroundColor: AppColors.surfaceElevated,
      ),
    );
  }
}
