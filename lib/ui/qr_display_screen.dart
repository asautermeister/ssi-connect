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
    this.footer,
  });

  final String payload;

  /// One line above the code restating what is encoded, so the right thing
  /// is being scanned.
  final String caption;

  /// What to do with it, below the code.
  final String hint;

  /// Optional control under the hint - the "carried over into SSI" tick
  /// belongs here, where the person is looking the moment the SSI app has
  /// swallowed the code.
  final Widget? footer;

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
          child: Column(
            children: [
              Text(
                hint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.inkMuted,
                ),
              ),
              if (footer case final footer?) ...[
                const SizedBox(height: AppSpacing.sm),
                footer,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// "Carried over into SSI", as a control that sits under a QR code.
///
/// A checkbox rather than a button: it says what the state *is*, and it can
/// be taken back. Someone who ticks the wrong dive should not have to go
/// looking for where to undo it.
class DiveTransferredCheckbox extends StatelessWidget {
  const DiveTransferredCheckbox({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.check_circle : Icons.circle_outlined,
              size: 22,
              color: value ? _transferredGreen : theme.colorScheme.outline,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(label, style: theme.textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}

/// The one green in the app. Deliberately not the accent colour: this says
/// "done", and it has to read that way on the white scan surface as well as
/// in a dark dive list.
const _transferredGreen = Color(0xFF2E7D32);

/// The tick as it appears next to a dive in a list - same colour, same
/// icon, no label, so the QR screen and the list say the same thing.
class DiveTransferredMark extends StatelessWidget {
  const DiveTransferredMark({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.check_circle, size: size, color: _transferredGreen);
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
    this.footer,
    this.actions,
  });

  final String title;
  final String payload;
  final String caption;
  final String hint;
  final Widget? footer;

  /// Top-right actions on the code's own page.
  ///
  /// What can be done with a contact lives here rather than on its row in
  /// the list: the row's job is to open the code, and an options button
  /// next to it competes with that one tap.
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light(),
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            title: Text(title),
            actions: actions,
          ),
          body: SafeArea(
            child: QrScanSurface(
              payload: payload,
              caption: caption,
              hint: hint,
              footer: footer,
            ),
          ),
        ),
      ),
    );
  }
}
