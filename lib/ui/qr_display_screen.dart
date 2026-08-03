import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'theme/app_theme.dart';

/// The white scan surface: what is encoded, the code itself, what to do
/// with it.
///
/// Extracted from [QrDisplayScreen] so the single code and the batch view
/// render identically. A camera is unforgiving about size and quiet zone,
/// so exactly one place decides them.
class QrScanSurface extends StatelessWidget {
  const QrScanSurface({
    super.key,
    required this.payload,
    required this.caption,
    required this.hint,
  });

  final String payload;

  /// One line above the code restating what is encoded, so the right thing
  /// is being scanned.
  final String caption;

  /// What to do with it, below the code.
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Text(
            caption,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: QrImageView(
                data: payload,
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
            hint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: palette.inkMuted),
          ),
        ),
      ],
    );
  }
}

/// Full-screen QR code for another device's camera.
///
/// Always light with a white quiet zone regardless of app theme: this is a
/// scan target, and a dark-mode QR code is unreliable for camera scanners.
///
/// Shared by the dive export and the buddy code - both are "hold this up
/// and let someone scan it", and they should look and behave the same.
class QrDisplayScreen extends StatelessWidget {
  const QrDisplayScreen({
    super.key,
    required this.title,
    required this.payload,
    required this.caption,
    required this.hint,
  });

  final String title;
  final String payload;
  final String caption;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light(),
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(backgroundColor: Colors.white, title: Text(title)),
          body: SafeArea(
            child: QrScanSurface(
              payload: payload,
              caption: caption,
              hint: hint,
            ),
          ),
        ),
      ),
    );
  }
}
