import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

import '../models/dive.dart';
import '../ssi/ssi_buddy_code.dart';
import '../ssi/ssi_qr_payload_builder.dart';
import 'format.dart';
import 'qr_display_screen.dart';
import 'widgets/error_state.dart';

/// The dive, as a QR code for the SSI app's scanner.
///
/// Buddies are deliberately not offered here. SSI's import format has no
/// field for them - a selection on this screen could only ever have been a
/// note to self, and a control that looks like it does something it
/// doesn't is worse than no control. They live in the buddy list instead,
/// where each one can be shown as their own code.
class QrScreen extends StatelessWidget {
  const QrScreen({super.key, required this.dive, this.diver});

  final Dive dive;

  /// SSI member the dive belongs to. When set, the payload attributes the
  /// dive to them; otherwise SSI files it under whoever is logged in.
  final SsiBuddyCode? diver;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final String payload;
    try {
      payload = SsiQrPayloadBuilder.build(dive, strings: s, diver: diver);
    } on ArgumentError catch (e) {
      return Scaffold(
        appBar: AppBar(title: Text(s.qrForSsi)),
        body: ErrorState(
          icon: Icons.error_outline,
          message: e.message.toString(),
        ),
      );
    }

    return QrDisplayScreen(
      title: s.scanWithSsiApp,
      payload: payload,
      caption:
          '${Fmt.weekday(dive.dateTime, s)}, ${Fmt.date(dive.dateTime)} · '
          '${Fmt.meters(dive.maxDepthMeters)} m · '
          '${Fmt.minutes(dive.duration)} min',
      hint: s.qrHintSingle,
    );
  }
}
