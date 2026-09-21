import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hather_app/core/utils/phone_number_formatter.dart';

/// Formats countdown from [expiresAt] for captain available-order UI.
///
/// Display only — does not change stored timestamps or expiration logic.
class OrderRemainingTime {
  const OrderRemainingTime._();

  static bool isExpired(DateTime expiresAt, {DateTime? now}) {
    final current = (now ?? DateTime.now()).toLocal();
    return !expiresAt.toLocal().isAfter(current);
  }

  /// Remaining duration; zero when expired.
  static Duration remaining(DateTime expiresAt, {DateTime? now}) {
    final current = (now ?? DateTime.now()).toLocal();
    final diff = expiresAt.toLocal().difference(current);
    if (diff.isNegative || diff.inSeconds <= 0) return Duration.zero;
    return diff;
  }

  /// Home card: `متبقي 10 دقائق`
  static String compactLabel(DateTime expiresAt, {DateTime? now}) {
    if (isExpired(expiresAt, now: now)) return 'انتهت مدة الطلب';
    return 'متبقي ${_phrase(remaining(expiresAt, now: now))}';
  }

  /// Detail value (no prefix): `10 دقائق`
  static String detailValue(DateTime expiresAt, {DateTime? now}) {
    if (isExpired(expiresAt, now: now)) return 'انتهت مدة الطلب';
    return _phrase(remaining(expiresAt, now: now));
  }

  static String _phrase(Duration d) {
    final totalMinutes = d.inMinutes;
    if (totalMinutes < 1) return 'أقل من دقيقة';

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours == 0) {
      return '${_en(minutes)} ${_minutesWord(minutes)}';
    }
    if (minutes == 0) {
      return hours == 1 ? 'ساعة' : '${_en(hours)} ${_hoursWord(hours)}';
    }
    if (hours == 1) {
      return 'ساعة و${_en(minutes)} ${_minutesWord(minutes)}';
    }
    return '${_en(hours)} ${_hoursWord(hours)} و${_en(minutes)} ${_minutesWord(minutes)}';
  }

  static String _en(int n) => PhoneNumberFormatter.toEnglishDigits('$n');

  static String _minutesWord(int n) => n == 1 ? 'دقيقة' : 'دقائق';

  static String _hoursWord(int n) => n == 1 ? 'ساعة' : 'ساعات';
}

/// Live remaining-time text that ticks locally from [expiresAt].
class OrderRemainingTimeText extends StatefulWidget {
  const OrderRemainingTimeText({
    required this.expiresAt,
    required this.builder,
    this.compact = true,
    super.key,
  });

  final DateTime expiresAt;

  /// When true uses [OrderRemainingTime.compactLabel], else [detailValue].
  final bool compact;
  final Widget Function(BuildContext context, String label, bool expired)
      builder;

  @override
  State<OrderRemainingTimeText> createState() => _OrderRemainingTimeTextState();
}

class _OrderRemainingTimeTextState extends State<OrderRemainingTimeText> {
  Timer? _timer;
  late String _label;
  late bool _expired;

  @override
  void initState() {
    super.initState();
    _refresh();
    _armTimer();
  }

  @override
  void didUpdateWidget(covariant OrderRemainingTimeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt ||
        oldWidget.compact != widget.compact) {
      _refresh();
      _armTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refresh() {
    _expired = OrderRemainingTime.isExpired(widget.expiresAt);
    _label = widget.compact
        ? OrderRemainingTime.compactLabel(widget.expiresAt)
        : OrderRemainingTime.detailValue(widget.expiresAt);
  }

  void _armTimer() {
    _timer?.cancel();
    if (_expired) return;

    final rem = OrderRemainingTime.remaining(widget.expiresAt);
    final interval = rem.inMinutes < 1
        ? const Duration(seconds: 15)
        : const Duration(minutes: 1);

    _timer = Timer(interval, () {
      if (!mounted) return;
      setState(_refresh);
      _armTimer();
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _label, _expired);
  }
}
