import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/dive.dart';
import '../ssi/ssi_qr_payload_builder.dart';

/// Full-screen, high-contrast QR code meant to be scanned by the SSI app's
/// camera on a *different* device - this tablet is the "second screen",
/// it's not the phone running SSI.
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
      error = e.message as String;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Mit SSI-App scannen')),
      body: Center(
        child: error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 18),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(24),
                child: QrImageView(
                  data: payload!,
                  size: 400,
                  backgroundColor: Colors.white,
                ),
              ),
      ),
    );
  }
}
