import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Pops when possible; otherwise navigates to [fallbackLocation].
///
/// Use for full-screen routes outside the shell so Android back never exits
/// the app unexpectedly.
void safeBack(BuildContext context, {required String fallbackLocation}) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallbackLocation);
  }
}
