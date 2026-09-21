import 'package:flutter/material.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_dimensions.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';

enum OrderProgressStepState { completed, current, upcoming }

/// Dark progress card for user delivery order detail (4 steps, RTL-friendly).
class OrderProgressTracker extends StatelessWidget {
  const OrderProgressTracker({
    required this.status,
    super.key,
  });

  final String status;

  static const int totalSteps = 4;

  static const stepTitles = [
    'تم إنشاء الطلب',
    'بانتظار كابتن',
    'جاري التوصيل',
    'تم التسليم',
  ];

  /// 1-based current step for normal flows; null when cancelled/expired/unknown.
  static int? currentStepFor(String status) {
    return switch (status) {
      'pending' => 2,
      'active' => 3,
      'completed' => 4,
      _ => null,
    };
  }

  static List<OrderProgressStepState> statesFor(String status) {
    if (status == 'cancelled') {
      return const [
        OrderProgressStepState.completed,
        OrderProgressStepState.upcoming,
        OrderProgressStepState.upcoming,
        OrderProgressStepState.upcoming,
      ];
    }
    if (status == 'completed') {
      return List.filled(totalSteps, OrderProgressStepState.completed);
    }
    final current = currentStepFor(status);
    if (current == null) {
      return List.filled(totalSteps, OrderProgressStepState.upcoming);
    }
    return List.generate(totalSteps, (i) {
      final step = i + 1;
      if (step < current) return OrderProgressStepState.completed;
      if (step == current) return OrderProgressStepState.current;
      return OrderProgressStepState.upcoming;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (status == 'expired') {
      return _SimpleStatusCard(
        message: 'انتهت مدة الطلب',
        color: AppColors.textMuted,
      );
    }

    if (status == 'cancelled') {
      return _ProgressCard(
        states: statesFor(status),
        accent: AppColors.error,
        description: 'تم إلغاء الطلب',
        descriptionColor: AppColors.error,
        stepLabel: null,
      );
    }

    final currentStep = currentStepFor(status) ?? 1;
    final isPending = status == 'pending';
    final accent = isPending ? AppColors.pendingOrder : AppColors.icon;

    final description = switch (status) {
      'pending' => 'بانتظار قبول أحد الكباتن',
      'active' => 'الكابتن استلم طلبك وهو الآن قيد التوصيل',
      'completed' => 'تم تسليم طلبك بنجاح',
      _ => '',
    };

    return _ProgressCard(
      states: statesFor(status),
      accent: accent,
      description: description,
      descriptionColor: isPending
          ? AppColors.pendingOrder.withValues(alpha: 0.95)
          : AppColors.textSecondary,
      stepLabel: '$currentStep من $totalSteps',
      semanticsLabels: stepTitles,
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.states,
    required this.accent,
    required this.description,
    required this.descriptionColor,
    required this.stepLabel,
    this.semanticsLabels,
  });

  final List<OrderProgressStepState> states;
  final Color accent;
  final String description;
  final Color descriptionColor;
  final String? stepLabel;
  final List<String>? semanticsLabels;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepperRow(
            states: states,
            accent: accent,
            semanticsLabels: semanticsLabels,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  description,
                  style: AppTextStyles.body.copyWith(
                    color: descriptionColor,
                    height: 1.35,
                  ),
                ),
              ),
              if (stepLabel != null) ...[
                const SizedBox(width: 12),
                Text(
                  stepLabel!,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.states,
    required this.accent,
    this.semanticsLabels,
  });

  final List<OrderProgressStepState> states;
  final Color accent;
  final List<String>? semanticsLabels;

  @override
  Widget build(BuildContext context) {
    // RTL Row: first child sits on the right → step 1 starts on the right.
    return Row(
      children: [
        for (var i = 0; i < states.length; i++) ...[
          if (i > 0)
            Expanded(
              child: _Connector(
                filled: states[i - 1] == OrderProgressStepState.completed,
                accent: accent,
              ),
            ),
          Semantics(
            label: semanticsLabels != null && i < semanticsLabels!.length
                ? semanticsLabels![i]
                : null,
            child: _StepDot(state: states[i], accent: accent),
          ),
        ],
      ],
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({
    required this.filled,
    required this.accent,
  });

  final bool filled;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        height: 2.5,
        decoration: BoxDecoration(
          color: filled
              ? accent.withValues(alpha: 0.9)
              : AppColors.border.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.state,
    required this.accent,
  });

  final OrderProgressStepState state;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    const size = 28.0;

    switch (state) {
      case OrderProgressStepState.completed:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.22),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.success, width: 1.6),
          ),
          child: Icon(
            Icons.check_rounded,
            size: 16,
            color: AppColors.success,
          ),
        );
      case OrderProgressStepState.current:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        );
      case OrderProgressStepState.upcoming:
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.textMuted.withValues(alpha: 0.55),
              width: 1.6,
            ),
          ),
        );
    }
  }
}

class _SimpleStatusCard extends StatelessWidget {
  const _SimpleStatusCard({
    required this.message,
    required this.color,
  });

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        message,
        style: AppTextStyles.bodyStrong.copyWith(color: color),
      ),
    );
  }
}
