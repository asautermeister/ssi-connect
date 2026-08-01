import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../ssi/ssi_buddy_code.dart';
import 'theme/app_theme.dart';

/// Camera view for reading the member QR code the SSI app shows under
/// "Dein QR-Code". Pops with the parsed [SsiBuddyCode], or null if the
/// user backed out.
///
/// Codes that parse as something else are ignored rather than reported one
/// by one: the camera sees a continuous stream of frames, so anything
/// pointed at it that isn't an SSI code would otherwise produce a flood of
/// error messages. A standing hint on screen covers that case instead.
class SsiScanScreen extends StatefulWidget {
  const SsiScanScreen({super.key});

  @override
  State<SsiScanScreen> createState() => _SsiScanScreenState();
}

class _SsiScanScreenState extends State<SsiScanScreen> {
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
      final code = SsiBuddyCode.tryParse(value);
      if (code != null) {
        _handled = true;
        Navigator.of(context).pop(code);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('SSI-QR-Code scannen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            tooltip: 'Licht',
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_outlined),
            tooltip: 'Kamera wechseln',
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
          const _ScanHint(),
        ],
      ),
    );
  }
}

class _ScanHint extends StatelessWidget {
  const _ScanHint();

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
          child: const Text(
            'In der SSI-App „Dein QR-Code" öffnen und die Kamera darauf '
            'richten.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 14),
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
                  ? 'Kein Kamerazugriff. Bitte in den Systemeinstellungen '
                        'für SSI Connect erlauben – oder die Mitgliedsnummer '
                        'von Hand eintragen.'
                  : 'Kamera konnte nicht gestartet werden. Die '
                        'Mitgliedsnummer lässt sich auch von Hand eintragen.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
