import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hather_app/core/errors/backend_error_mapper.dart';
import 'package:hather_app/core/errors/failure_messages.dart';
import 'package:hather_app/core/errors/failures.dart';
import 'package:hather_app/core/theme/app_colors.dart';
import 'package:hather_app/core/theme/app_text_styles.dart';
import 'package:hather_app/core/widgets/app_text_field.dart';
import 'package:hather_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:hather_app/l10n/app_localizations.dart';

void _deleteAccountLog(String step) {
  if (!kDebugMode) return;
  debugPrint('DELETE_ACCOUNT: $step');
}

void _clearDeleteLoadingUi(ScaffoldMessengerState? messenger) {
  _deleteAccountLog('clearing loading UI');
  messenger?.clearSnackBars();
  messenger?.hideCurrentSnackBar();
}

/// Two-step delete-account flow (intro → password confirm) for user & captain.
///
/// Loading lives inside the confirm dialog (not a persistent SnackBar) so an
/// auth redirect to `/login` cannot leave a spinner bar on the login screen.
Future<void> showDeleteAccountFlow(
  BuildContext context, {
  required WidgetRef ref,
  bool warnActiveSubscription = false,
}) async {
  final l10n = AppLocalizations.of(context);
  // Capture root messenger before any await — survives account-route teardown.
  final messenger = ScaffoldMessenger.maybeOf(context);

  final cont = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.accountDeleteAccount,
                style: AppTextStyles.bodyStrong.copyWith(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.accountDeleteIntroBody,
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                l10n.accountDeleteIrreversibleWarning,
                style: AppTextStyles.bodyStrong.copyWith(
                  color: AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
              if (warnActiveSubscription) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.accountDeleteSubscriptionWarning,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.pendingOrder,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(l10n.cancelAction),
              ),
              const SizedBox(height: 4),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(l10n.accountDeleteContinueAction),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (cont != true || !context.mounted) return;

  final confirmed = await showDialog<_DeleteConfirmResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _DeleteAccountConfirmDialog(ref: ref),
  );

  _deleteAccountLog('closing confirmation UI');
  _clearDeleteLoadingUi(messenger);

  final auth = ref.read(authControllerProvider);
  final deletedViaAuthRedirect =
      confirmed == null && !auth.isAuthenticated;

  if (confirmed?.ok == true || deletedViaAuthRedirect) {
    _deleteAccountLog('auth signed out');
    _clearDeleteLoadingUi(messenger);
    // Auth redirect owns navigation when the account route was torn down.
    // If still mounted, finish with a brief success then go('/login') (idempotent).
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(l10n.accountDeleteSuccessTitle),
          content: Text(l10n.accountDeleteSuccessBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.okAction),
            ),
          ],
        ),
      );
      if (context.mounted) {
        _deleteAccountLog('navigation login');
        context.go('/login');
      } else {
        _deleteAccountLog('navigation login');
      }
    } else {
      _deleteAccountLog('navigation login');
    }
    _clearDeleteLoadingUi(messenger);
    _deleteAccountLog('flow disposed');
    return;
  }

  if (confirmed == null || !confirmed.proceed) {
    _deleteAccountLog('flow disposed');
    return;
  }

  // Unexpected non-success proceed — should not happen; stay put.
  _deleteAccountLog('flow disposed');
}

String _mapDeleteFailure(
  BuildContext context,
  AppLocalizations l10n,
  Failure? failure,
) {
  final raw = failure?.message?.trim() ?? '';
  if (raw.contains('طلب نشط') && raw.contains('الكابتن')) {
    return l10n.accountDeleteActiveCaptainOrder;
  }
  if (raw.contains('طلب نشط')) {
    return l10n.accountDeleteActiveUserOrder;
  }
  if (raw.contains('كلمة المرور')) {
    return raw;
  }
  if (raw.isNotEmpty && !isTechnicalUserMessage(raw)) {
    return raw;
  }
  if (failure != null) {
    return mapFailureToMessage(context, failure);
  }
  return l10n.accountDeleteFailed;
}

class _DeleteConfirmResult {
  const _DeleteConfirmResult._({
    required this.proceed,
    required this.ok,
  });

  factory _DeleteConfirmResult.cancelled() =>
      const _DeleteConfirmResult._(proceed: false, ok: false);

  factory _DeleteConfirmResult.success() =>
      const _DeleteConfirmResult._(proceed: true, ok: true);

  final bool proceed;
  final bool ok;
}

class _DeleteAccountConfirmDialog extends StatefulWidget {
  const _DeleteAccountConfirmDialog({required this.ref});

  final WidgetRef ref;

  @override
  State<_DeleteAccountConfirmDialog> createState() =>
      _DeleteAccountConfirmDialogState();
}

class _DeleteAccountConfirmDialogState
    extends State<_DeleteAccountConfirmDialog> {
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final l10n = AppLocalizations.of(context);
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() => _error = l10n.accountDeletePasswordRequired);
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() {
      _submitting = true;
      _error = null;
    });
    _deleteAccountLog('request started');

    try {
      final ok = await widget.ref
          .read(authControllerProvider.notifier)
          .deleteMyAccount(password: password);

      if (ok) {
        _deleteAccountLog('backend success');
        _deleteAccountLog('auth signed out');
        _clearDeleteLoadingUi(messenger);
        if (!mounted) return;
        Navigator.of(context).pop(_DeleteConfirmResult.success());
        return;
      }

      _deleteAccountLog('backend failure');
      if (!mounted) return;
      final failure = widget.ref.read(authControllerProvider).failure;
      final message = _mapDeleteFailure(context, l10n, failure);
      setState(() {
        _submitting = false;
        _error = message;
      });
    } catch (_) {
      _deleteAccountLog('backend failure');
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = l10n.accountDeleteFailed;
      });
    } finally {
      // Always drop any leftover bars even if auth already redirected.
      _clearDeleteLoadingUi(messenger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: !_submitting,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          l10n.accountDeleteConfirmTitle,
          style: AppTextStyles.bodyStrong,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.accountDeleteConfirmBody, style: AppTextStyles.body),
            const SizedBox(height: 14),
            AppTextField(
              controller: _passwordController,
              hintText: l10n.accountDeletePasswordLabel,
              obscureText: true,
              enabled: !_submitting,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTextStyles.caption.copyWith(color: AppColors.error),
              ),
            ],
            if (_submitting) ...[
              const SizedBox(height: 16),
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _submitting
                ? null
                : () => Navigator.of(context).pop(
                      _DeleteConfirmResult.cancelled(),
                    ),
            child: Text(l10n.accountDeleteBackAction),
          ),
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: Text(
              l10n.accountDeleteFinalAction,
              style: TextStyle(
                color: _submitting ? AppColors.textSecondary : AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
