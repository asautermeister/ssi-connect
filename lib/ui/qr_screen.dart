import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/dive.dart';
import '../ssi/ssi_qr_payload_builder.dart';
import 'format.dart';
import 'theme/app_theme.dart';
import 'widgets/error_state.dart';

/// Full-screen, high-contrast QR code for the SSI app's scanner.
///
/// Always light with a white quiet zone regardless of app theme: this is a
/// scan target, and a dark-mode QR code is unreliable for camera scanners.
/// The dive is restated above it so the right one is being exported.
class QrScreen extends StatelessWidget {
  const QrScreen({super.key, required this.dive});

  final Dive dive;

  @override
  Widget build(BuildContext context) {
    String? payload;
    String? error;
    try {
      payload = SsiQrPayloadBuilder.build(dive);
    } on ArgumentError catch (e) {
      error = e.message.toString();
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('QR-Code')),
        body: ErrorState(icon: Icons.error_outline, message: error),
      );
    }

    return Theme(
      data: AppTheme.light(),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final palette = theme.extension<AppPalette>()!;

          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              title: const Text('Mit SSI-App scannen'),
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: Text(
                      '${Fmt.date(dive.dateTime)} · '
                      '${Fmt.meters(dive.maxDepthMeters)} m · '
                      '${Fmt.minutes(dive.duration)} min',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: QrImageView(
                          data: payload!,
                          size: 380,
                          backgroundColor: Colors.white,
                          // Quiet zone: scanners need clear margin.
                          padding: const EdgeInsets.all(AppSpacing.lg),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      0,
                      AppSpacing.xl,
                      AppSpacing.xl,
                    ),
                    child: Text(
                      'In der SSI-App einen Tauchgang hinzufügen und '
                      '„QR-Code scannen" wählen.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
