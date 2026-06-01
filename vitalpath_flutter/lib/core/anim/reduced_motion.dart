import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// True when the OS has "reduce motion" / "remove animations" enabled.
bool prefersReducedMotion(BuildContext context) {
  final mq = MediaQuery.maybeOf(context);
  return mq?.disableAnimations ?? false;
}

/// Fires a haptic only when reduced motion is OFF (haptics are part of the
/// motion feedback system we suppress for accessibility).
void safeHaptic(BuildContext context, {bool medium = false}) {
  if (prefersReducedMotion(context)) return;
  medium ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact();
}
