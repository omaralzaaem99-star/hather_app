import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hather_app/core/routing/authenticated_routes.dart';
import 'package:hather_app/features/support/core/support_launcher.dart';
import 'package:hather_app/features/support/presentation/providers/support_providers.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens configured admin support channels; falls back to in-app support.
Future<void> contactAdminSupport({
  required BuildContext context,
  required WidgetRef ref,
  required VoidCallback onLaunchFailed,
}) async {
  final settings = await ref.read(supportSettingsProvider.future);

  if (settings.hasWhatsappChannel) {
    final launched = await _launchFirstAvailable(
      SupportLauncher.whatsAppLaunchUris(settings.whatsappNumber!),
    );
    if (launched) return;
  }

  if (settings.hasPhoneChannel) {
    final launched = await _launchFirstAvailable([
      SupportLauncher.telUri(settings.phoneNumber!),
    ]);
    if (launched) return;
  }

  if (settings.hasEmailChannel) {
    final launched = await _launchFirstAvailable([
      SupportLauncher.mailtoUri(settings.emailAddress!),
    ]);
    if (launched) return;
  }

  if (!context.mounted) return;
  if (settings.hasAnyChannel) {
    onLaunchFailed();
    return;
  }

  context.push(AuthenticatedRoutes.support);
}

Future<bool> _launchFirstAvailable(Iterable<Uri> uris) async {
  for (final uri in uris) {
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (launched) return true;
    } on Object {
      // Try next target.
    }
  }
  return false;
}
