import 'package:flutter/material.dart';
import 'app_widgets.dart';

/// Records a dose, shows an "Undo" snackbar for ~4s, then either reverses the
/// dose (if Undo tapped) or awards HP (if [awardHp] provided — patient path).
///
/// * [record] writes the dose and returns the logged timestamp.
/// * [undo] reverses the dose by that timestamp.
/// * [awardHp] null → family path (no HP). Non-null → patient path.
Future<void> logDoseWithUndo(
  BuildContext context, {
  required Future<DateTime> Function() record,
  required Future<void> Function(DateTime ts) undo,
  Future<int> Function()? awardHp,
}) async {
  final DateTime ts;
  try {
    ts = await record();
  } catch (_) {
    if (context.mounted) {
      AppSnackBar.error(context, 'Could not log dose. Please try again.');
    }
    return;
  }
  if (!context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final controller = messenger.showSnackBar(
    SnackBar(
      content: const Text('Dose logged'),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(label: 'Undo', onPressed: () {}),
    ),
  );

  final reason = await controller.closed;

  if (reason == SnackBarClosedReason.action) {
    await undo(ts);
    return;
  }
  if (awardHp != null) {
    final hp = await awardHp();
    if (hp > 0 && context.mounted) {
      AppSnackBar.success(context, '+$hp HP  Dose logged!');
    }
  }
}
