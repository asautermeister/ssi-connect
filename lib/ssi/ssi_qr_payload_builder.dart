import '../models/dive.dart';
import 'ssi_buddy_code.dart';

/// Builds the text payload the official SSI app (com.divessi.ssi) expects
/// when scanning a QR code to import a dive.
///
/// The format is not officially documented. It was first reconstructed from
/// independently-reported example payloads, then confirmed against a real
/// QR code exported from the SSI app itself:
/// `dive;noid;dive_type:2;divetime:92.0;datetime:202511080856;depth_m:44.0;
/// site:1074;var_watertype_id:5;var_divetype_id:24;user_master_id:...;
/// user_firstname:...;user_lastname:...;user_leader_id:`
///
/// Key findings from that real example:
/// - `depth_m` and `divetime` always carry one decimal place, even for
///   whole numbers (`44.0`, not `44`).
/// - `divetime` is dive duration in *minutes*, as a float (so fractional
///   minutes are possible), not whole seconds/minutes.
/// - Field order doesn't matter - the real example has `divetime` before
///   `datetime`, the reverse of earlier reference payloads, so this is
///   evidently parsed as an order-independent key/value bag.
///
/// Emitted: `dive_type`, `datetime`, `divetime`, `depth_m`, plus
/// `watertemp_c` when Garmin reported one, plus the `user_*` fields when
/// an SSI identity has been scanned for the account.
///
/// Deliberately left out, because filling them would mean inventing values
/// for code tables SSI has never published:
/// - `site` - an SSI dive-site id. Garmin only has GPS coordinates.
/// - `var_weather_id`, `var_entry_id`, `var_water_body_id`,
///   `var_current_id`, `var_surface_id`, `vis_m` - subjective conditions
///   that aren't in the dive computer's data at all.
/// - `var_watertype_id` - Garmin does report a water type and density
///   (1025 kg/m3 = salt), but SSI's numbering for it is unknown.
/// - `var_divetype_id` - both captured exports carry `24`; copying a
///   constant whose meaning nobody knows would be cargo cult.
/// - `airtemp_c` - Garmin's `maxTemperature` is plausibly the air reading,
///   but that is a guess, and a wrong air temperature is worse than none.
/// - `user_leader_id` - empty in both captured exports.
///
/// An omitted field simply isn't imported; a wrongly guessed one would be
/// silently wrong in the user's logbook, which is the worse failure.
class SsiQrPayloadBuilder {
  const SsiQrPayloadBuilder._();

  /// Default recreational scuba dive. The real example above used `2`
  /// (technical/cave dive, matching its dive site/dive shop) - the mapping
  /// for `dive_type` isn't public, so this stays the same default used by
  /// prior reference payloads for ordinary recreational dives, which is
  /// what this app targets.
  static const _diveTypeScuba = 0;

  /// [diver] attributes the dive to an SSI member. Optional: without it
  /// the payload is exactly what it was before, and SSI attributes the
  /// scanned dive to whoever is logged in.
  ///
  /// Throws [ArgumentError] if [dive] is missing a field the payload can't
  /// be built without (max depth or duration).
  static String build(Dive dive, {SsiBuddyCode? diver}) {
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
      'divetime:${_formatFixed(duration.inSeconds / 60.0)}',
      'depth_m:${_formatFixed(maxDepth)}',
    ];

    final waterTemp = dive.waterTemperatureCelsius;
    if (waterTemp != null) {
      fields.add('watertemp_c:${_formatFixed(waterTemp)}');
    }

    if (diver != null) {
      // Names are echoed alongside the id exactly as SSI's own export
      // does; the id is what actually identifies the member.
      fields.add('user_master_id:${diver.memberId}');
      final firstName = diver.firstName;
      final lastName = diver.lastName;
      if (firstName != null) fields.add('user_firstname:$firstName');
      if (lastName != null) fields.add('user_lastname:$lastName');
    }

    return 'dive;noid;${fields.join(';')}';
  }

  static String _formatDateTime(DateTime dateTime) {
    String pad(int n, [int width = 2]) => n.toString().padLeft(width, '0');
    return '${pad(dateTime.year, 4)}${pad(dateTime.month)}${pad(dateTime.day)}'
        '${pad(dateTime.hour)}${pad(dateTime.minute)}';
  }

  /// Always one decimal place, matching the real captured payload
  /// (`depth_m:44.0`, `divetime:92.0`) - unlike some earlier reference
  /// examples, whole numbers are NOT trimmed to integers here.
  static String _formatFixed(double value) => value.toStringAsFixed(1);
}
