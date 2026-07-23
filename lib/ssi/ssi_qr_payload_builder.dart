import '../models/dive.dart';

/// Builds the text payload the official SSI app (com.divessi.ssi) expects
/// when scanning a QR code to import a dive.
///
/// The format is not officially documented - it was reconstructed from
/// several independently-reported example payloads, e.g.:
/// `dive;noid;dive_type:0;datetime:201907211000;divetime:38;depth_m:12.8;
/// site:119506;var_weather_id:1;...;watertemp_c:26;airtemp_c:26;vis_m:20`
///
/// Only the fields believed to be required are emitted: `dive_type`,
/// `datetime`, `divetime`, `depth_m`, plus `watertemp_c` when available.
/// Condition codes (weather/entry/current/...), the SSI dive-site id and
/// buddy references are left out deliberately - their value vocabularies
/// aren't public, and buddy-tagging is a later iteration (see
/// GarminAccount.ssiBuddyId).
class SsiQrPayloadBuilder {
  const SsiQrPayloadBuilder._();

  /// Recreational single/multi-gas scuba dive. The only `dive_type` value
  /// observed in reference payloads; SSI's other codes aren't documented.
  static const _diveTypeScuba = 0;

  /// Throws [ArgumentError] if [dive] is missing a field the payload can't
  /// be built without (max depth or duration).
  static String build(Dive dive) {
    final maxDepth = dive.maxDepthMeters;
    final duration = dive.duration;
    if (maxDepth == null) {
      throw ArgumentError(
        'Tauchgang hat keine maximale Tiefe - QR-Code nicht möglich.',
      );
    }
    if (duration == null) {
      throw ArgumentError('Tauchgang hat keine Dauer - QR-Code nicht möglich.');
    }

    final fields = <String>[
      'dive_type:$_diveTypeScuba',
      'datetime:${_formatDateTime(dive.dateTime)}',
      'divetime:${duration.inMinutes}',
      'depth_m:${_formatNumber(maxDepth)}',
    ];

    final waterTemp = dive.waterTemperatureCelsius;
    if (waterTemp != null) {
      fields.add('watertemp_c:${_formatNumber(waterTemp)}');
    }

    return 'dive;noid;${fields.join(';')}';
  }

  static String _formatDateTime(DateTime dateTime) {
    String pad(int n, [int width = 2]) => n.toString().padLeft(width, '0');
    return '${pad(dateTime.year, 4)}${pad(dateTime.month)}${pad(dateTime.day)}'
        '${pad(dateTime.hour)}${pad(dateTime.minute)}';
  }

  /// Whole numbers are emitted without a decimal point (matches observed
  /// payloads using both "18" and "12.8"), fractional ones with one digit.
  static String _formatNumber(double value) {
    final rounded = double.parse(value.toStringAsFixed(1));
    if (rounded == rounded.roundToDouble()) {
      return rounded.round().toString();
    }
    return rounded.toStringAsFixed(1);
  }
}
