import 'package:flutter/material.dart';

import '../../models/dive_type.dart';
import '../theme/app_theme.dart';

/// Round badge showing what kind of dive this was: freediving fins, one
/// cylinder, two cylinders, or a rebreather loop.
///
/// Hand-drawn rather than icon-font glyphs because no standard icon set
/// ships dive cylinders or freediving fins. The shapes are deliberately
/// simple - they are read at 40px in a list, so they need a recognisable
/// silhouette, not detail.
///
/// The badge is decorative in the accessibility sense: the dive type is
/// also written out in the card, so nothing depends on recognising the
/// picture. A [Semantics] label is still attached for screen readers.
class DiveTypeIcon extends StatelessWidget {
  const DiveTypeIcon({super.key, required this.type, this.size = 40});

  final DiveType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: type.label,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.primary,
          shape: BoxShape.circle,
        ),
        child: CustomPaint(
          painter: _DiveTypePainter(
            type: type,
            color: scheme.onPrimary,
            badgeColor: scheme.primary,
          ),
        ),
      ),
    );
  }
}

/// The dive-type badge with the diver's running dive number set above it.
///
/// Number and badge belong together as one block on the left edge of a
/// dive, so they are laid out here rather than assembled at each call
/// site. The number is omitted when the source didn't report one, and the
/// block then collapses to just the badge.
class DiveTypeBadge extends StatelessWidget {
  const DiveTypeBadge({
    super.key,
    required this.type,
    this.diveNumber,
    this.size = 40,
  });

  final DiveType type;
  final int? diveNumber;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (diveNumber != null) ...[
          Text(
            '# $diveNumber',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        DiveTypeIcon(type: type, size: size),
      ],
    );
  }
}

class _DiveTypePainter extends CustomPainter {
  const _DiveTypePainter({
    required this.type,
    required this.color,
    required this.badgeColor,
  });

  final DiveType type;
  final Color color;

  /// The circle behind the glyph. Used to knock shapes back out of a
  /// filled form (the mask lens) - painting in the badge colour rather
  /// than clearing, since clearing without its own layer would punch
  /// through to whatever is behind the badge.
  final Color badgeColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Everything below is authored against a 24x24 box and scaled, so the
    // shapes stay proportional at any badge size.
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (type) {
      case DiveType.apnea:
        _paintFins(canvas, fill);
      case DiveType.singleGas:
        _paintCylinder(canvas, fill, centerX: 12);
      case DiveType.multiGas:
        _paintCylinder(canvas, fill, centerX: 8.6, width: 5.4);
        _paintCylinder(canvas, fill, centerX: 15.4, width: 5.4);
      case DiveType.rebreather:
        _paintRebreather(canvas, fill, stroke);
      case DiveType.scuba:
        _paintCylinder(canvas, fill, centerX: 12);
    }

    canvas.restore();
  }

  /// A pair of long freediving fins, standing on their heels and splayed
  /// apart at the tips.
  ///
  /// Two upright shapes risk reading as the multi-gas cylinders, so the
  /// difference is carried by three things a tank doesn't have: the outward
  /// splay, the blade widening toward a rounded tip (a cylinder is
  /// parallel-sided), and the waisted foot pocket at the bottom. An earlier
  /// monofin silhouette avoided the confusion but looked like a sprouting
  /// seedling.
  void _paintFins(Canvas canvas, Paint fill) {
    _paintFin(canvas, fill, pivotX: 9.7, radians: -0.21);
    _paintFin(canvas, fill, pivotX: 14.3, radians: 0.21);
  }

  /// One fin, drawn upright around a pivot at its heel and then rotated
  /// into place, so both fins are the same shape mirrored rather than two
  /// hand-tuned outlines.
  void _paintFin(
    Canvas canvas,
    Paint fill, {
    required double pivotX,
    required double radians,
  }) {
    canvas.save();
    canvas.translate(pivotX, 14.2);
    canvas.rotate(radians);

    final fin = Path()
      // Heel of the foot pocket, the widest point at the bottom.
      ..moveTo(-2.3, 2.8)
      // Instep: waisted where the pocket meets the blade, which is what
      // makes the foot pocket visible as a separate part.
      ..quadraticBezierTo(-2.6, 0.4, -1.5, -1.6)
      // Blade, widening slightly toward the tip.
      ..lineTo(-2.5, -11.4)
      // Rounded tip.
      ..quadraticBezierTo(0, -13.8, 2.5, -11.4)
      ..lineTo(1.5, -1.6)
      ..quadraticBezierTo(2.6, 0.4, 2.3, 2.8)
      // Heel, rounded off.
      ..quadraticBezierTo(0, 4.0, -2.3, 2.8)
      ..close();
    canvas.drawPath(fin, fill);

    canvas.restore();
  }

  /// One cylinder: a rounded tank body with a valve stub on top.
  void _paintCylinder(
    Canvas canvas,
    Paint fill, {
    required double centerX,
    double width = 7.2,
  }) {
    final half = width / 2;

    // Valve.
    canvas.drawRRect(
      RRect.fromLTRBR(
        centerX - 1.1,
        3.2,
        centerX + 1.1,
        6.2,
        const Radius.circular(0.5),
      ),
      fill,
    );
    // Body.
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        centerX - half,
        5.6,
        centerX + half,
        20.4,
        topLeft: Radius.circular(half * 0.7),
        topRight: Radius.circular(half * 0.7),
        bottomLeft: Radius.circular(half * 0.45),
        bottomRight: Radius.circular(half * 0.45),
      ),
      fill,
    );
  }

  /// A rebreather: the full-face mask with the breathing loop curving away
  /// from it on both sides.
  void _paintRebreather(Canvas canvas, Paint fill, Paint stroke) {
    // Mask body.
    canvas.drawRRect(
      RRect.fromLTRBR(6.6, 7.4, 17.4, 15.2, const Radius.circular(3.4)),
      fill,
    );
    // Lens, so the mask reads as a mask rather than a blob.
    canvas.drawRRect(
      RRect.fromLTRBR(8.4, 9.2, 15.6, 12.6, const Radius.circular(1.8)),
      Paint()..color = badgeColor,
    );
    // Breathing loop, one hose each side.
    final loop = Path()
      ..moveTo(6.8, 14)
      ..cubicTo(3.6, 15.6, 3.8, 19.2, 7.4, 19.8)
      ..moveTo(17.2, 14)
      ..cubicTo(20.4, 15.6, 20.2, 19.2, 16.6, 19.8);
    canvas.drawPath(loop, stroke);
  }

  @override
  bool shouldRepaint(_DiveTypePainter oldDelegate) =>
      oldDelegate.type != type ||
      oldDelegate.color != color ||
      oldDelegate.badgeColor != badgeColor;
}
