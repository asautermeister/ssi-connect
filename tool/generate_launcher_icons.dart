// Draws the launcher icon and writes the three PNGs `flutter_launcher_icons`
// consumes. Kept in the repo so the icon can be adjusted by editing shapes
// here rather than by editing pixels somewhere else.
//
//   flutter test tool/generate_launcher_icons.dart
//   dart run flutter_launcher_icons
//
// It is a test file only because drawing needs Flutter's canvas; it asserts
// nothing beyond the files being written.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adaptive icons are authored on a 108x108 canvas of which only the
/// central circle of diameter 72 (66%) is guaranteed to survive whatever
/// mask a launcher applies.
const _canvas = 108.0;

/// Rendered size. 1024 is what the iOS App Store asset needs; every
/// Android density is downscaled from it.
const _pixels = 1024;

const _background = Color(0xFFE3F0EE);
const _ink = Color(0xFF00494B);
const _inkSoft = Color(0xFF7FBDB6);

/// The dive profile: surface, descent, bottom time, safety stop, ascent.
///
/// The safety stop is the load-bearing detail - without that step the
/// outline is symmetrical and reads as a cup rather than as a dive.
///
/// The profile stays inside the guaranteed circle; the surface line
/// deliberately runs past it, so a round mask crops it into a waterline
/// spanning the whole icon instead of leaving it floating.
void _paintArt(Canvas canvas, {required Color ink, required Color inkSoft}) {
  canvas.drawRRect(
    RRect.fromLTRBR(14, 26, 94, 33, const Radius.circular(4)),
    Paint()..color = inkSoft,
  );

  canvas.drawPath(
    Path()
      ..moveTo(24, 40)
      ..lineTo(36, 76)
      ..lineTo(66, 76)
      ..lineTo(74, 56)
      ..lineTo(84, 56),
    Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );
}

Future<void> _write(
  String path, {
  required bool withBackground,
  required Color ink,
  required Color inkSoft,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(_pixels / _canvas);
  if (withBackground) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, _canvas, _canvas),
      Paint()..color = _background,
    );
  }
  _paintArt(canvas, ink: ink, inkSoft: inkSoft);

  final image = await recorder.endRecording().toImage(_pixels, _pixels);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('write launcher icon assets', (tester) async {
    await tester.runAsync(() async {
      // Full bleed, for iOS and pre-adaptive Android.
      await _write(
        'assets/icon/icon.png',
        withBackground: true,
        ink: _ink,
        inkSoft: _inkSoft,
      );
      // Adaptive foreground: art only, on the same 108 canvas, so it must
      // be configured with an inset of 0.
      await _write(
        'assets/icon/icon_foreground.png',
        withBackground: false,
        ink: _ink,
        inkSoft: _inkSoft,
      );
      // Themed icons (Android 13+): one flat shape the system tints. The
      // softer tone has to collapse into the main one without the drawing
      // falling apart - here it does, because line and profile never
      // touch.
      await _write(
        'assets/icon/icon_monochrome.png',
        withBackground: false,
        ink: const Color(0xFF000000),
        inkSoft: const Color(0xFF000000),
      );
    });
  });
}
