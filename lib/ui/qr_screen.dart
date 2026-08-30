import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';

import '../dives/exported_dives_controller.dart';
import '../models/dive.dart';
import '../ssi/dive_site.dart';
import '../ssi/ssi_buddy_code.dart';
import '../ssi/ssi_qr_payload_builder.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'format.dart';
import 'qr_display_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_card.dart';
import 'widgets/error_state.dart';

/// The dive, as a QR code for the SSI app's scanner.
///
/// Buddies are deliberately not offered here. SSI's import format has no
/// field for them - a selection on this screen could only ever have been a
/// note to self, and a control that looks like it does something it
/// doesn't is worse than no control. They live in the buddy list instead,
/// where each one can be shown as their own code.
class QrScreen extends StatelessWidget {
  const QrScreen({super.key, required this.dive, this.diver, this.site});

  final Dive dive;

  /// SSI member the dive belongs to. When set, the payload attributes the
  /// dive to them; otherwise SSI files it under whoever is logged in.
  final SsiBuddyCode? diver;

  /// Dive site the user matched this dive to; see
  /// [SsiQrPayloadBuilder.build].
  final DiveSite? site;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final String payload;
    try {
      payload = SsiQrPayloadBuilder.build(
        dive,
        strings: s,
        diver: diver,
        site: site,
      );
    } on ArgumentError catch (e) {
      return Scaffold(
        appBar: AppBar(title: Text(s.qrForSsi)),
        body: ErrorState(
          icon: Icons.error_outline,
          message: e.message.toString(),
        ),
      );
    }

    final exported = context.watch<ExportedDivesController>();

    return QrDisplayScreen(
      title: s.scanWithSsiApp,
      payload: payload,
      caption:
          '${Fmt.weekday(dive.dateTime, s)}, ${Fmt.date(dive.dateTime)} · '
          '${Fmt.meters(dive.maxDepthMeters)} m · '
          '${Fmt.minutes(dive.duration)} min',
      hint: s.qrHintSingle,
      // Ticked here rather than on the way out: this is the screen you are
      // looking at the moment the SSI app has taken the code.
      footer: DiveTransferredCheckbox(
        label: s.transferredToSsi,
        value: exported.isTransferred(dive),
        onChanged: (value) => exported.setTransferred(dive.id, value),
      ),
    );
  }
}

/// The dive's QR code, on the page it belongs to.
///
/// The same payload and the same white surface as [QrScreen], one screen
/// earlier: the code is what the app is for, and reaching it used to cost
/// two taps and a screen that showed nothing the detail page could not.
///
/// Always light, whatever the app theme - a dark QR code is unreliable for
/// camera scanners, and half a card in light theme is less confusing than a
/// code that cannot be read.
class DiveQrCard extends StatelessWidget {
  const DiveQrCard({super.key, required this.dive, this.diver, this.site});

  final Dive dive;
  final SsiBuddyCode? diver;

  /// The site the dive is filed at. Part of the payload, so a change here
  /// has to reach the code - which it does, because this widget is rebuilt
  /// with the page that owns the choice.
  final DiveSite? site;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final String payload;
    try {
      payload = SsiQrPayloadBuilder.build(
        dive,
        strings: s,
        diver: diver,
        site: site,
      );
    } on ArgumentError catch (e) {
      // Said in place of the code, not instead of the screen: the rest of
      // the dive is still worth reading.
      return AppCard(
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              size: 18,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(e.message.toString())),
          ],
        ),
      );
    }

    final exported = context.watch<ExportedDivesController>();

    return Theme(
      data: AppTheme.light(),
      child: Builder(
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Column(
            children: [
              QrImageView(
                data: payload,
                size: 300,
                backgroundColor: Colors.white,
                // Quiet zone: scanners need clear margin.
                padding: const EdgeInsets.all(AppSpacing.lg),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Text(
                  s.qrHintSingle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Ticked where the code is: this is what one is looking at
              // the moment the SSI app has swallowed it.
              DiveTransferredCheckbox(
                label: s.transferredToSsi,
                value: exported.isTransferred(dive),
                onChanged: (value) => exported.setTransferred(dive.id, value),
              ),
              // Still a way to the full screen. A card in a scrolling list
              // is a compromise on size, and a camera that will not read
              // this one may well read a bigger one.
              TextButton.icon(
                icon: const Icon(Icons.fullscreen, size: 18),
                label: Text(s.qrFullScreen),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        QrScreen(dive: dive, diver: diver, site: site),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
