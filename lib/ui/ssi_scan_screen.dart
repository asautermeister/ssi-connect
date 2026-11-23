import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../ssi/ssi_buddy_code.dart';
import '../ssi/ssi_center_code.dart';
import 'theme/app_theme.dart';

/// Camera view that pops with the first scanned code [parse] accepts.
///
/// Codes that parse as something else are ignored rather than reported one
/// by one: the camera sees a continuous stream of frames, so anything
/// pointed at it that isn't wanted would otherwise produce a flood of error
/// messages. The standing [hint] on screen covers that case instead.
class QrScanScreen<T extends Object> extends StatefulWidget {
  const QrScanScreen({
    super.key,
    required this.parse,
    required this.title,
    required this.hint,
  });

  /// Returns the value to pop with, or null to keep scanning.
  final T? Function(String raw) parse;
  final String title;
  final String hint;

  @override
  State<QrScanScreen<T>> createState() => _QrScanScreenState<T>();
}

class _QrScanScreenState<T extends Object> extends State<QrScanScreen<T>> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  /// Guards against the detector firing again while the pop is in flight.
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value == null) continue;
      final parsed = widget.parse(value);
      if (parsed != null) {
        _handled = true;
        Navigator.of(context).pop(parsed);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            tooltip: s.torch,
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_outlined),
            tooltip: s.switchCamera,
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _ScannerError(error: error),
          ),
          _ScanHint(text: widget.hint),
        ],
      ),
    );
  }
}

/// Reads the member QR code the SSI app shows under "Dein QR-Code". Pops
/// with the parsed [SsiBuddyCode], or null if the user backed out.
///
/// Members only: this is what the account screen uses to learn who its
/// owner is, and a dive centre is not an answer to that question.
class SsiScanScreen extends StatelessWidget {
  const SsiScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return QrScanScreen<SsiBuddyCode>(
      parse: SsiBuddyCode.tryParse,
      title: s.scanSsiQr,
      hint: s.scanHintMember,
    );
  }
}

/// Reads either kind of SSI code and pops with whatever it turned out to
/// be: a member ([SsiBuddyCode]) or a dive centre ([SsiCenterCode]).
///
/// One scanner for both, because the two look identical to the person
/// holding the camera - the marker inside decides. Asking beforehand which
/// kind is about to be scanned would only be a question the code itself
/// already answers.
class SsiCodeScanScreen extends StatelessWidget {
  const SsiCodeScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return QrScanScreen<Object>(
      parse: (raw) => SsiBuddyCode.tryParse(raw) ?? SsiCenterCode.tryParse(raw),
      title: s.scanSsiQr,
      hint: s.scanHintMemberOrCentre,
    );
  }
}

class _ScanHint extends StatelessWidget {
  const _ScanHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.xl),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    // The one case worth naming separately: without camera permission the
    // scanner can never work, and the fix is in system settings, not here.
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white70,
              size: 40,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              denied
                  ? AppStrings.of(context).cameraDenied
                  : AppStrings.of(context).cameraFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
