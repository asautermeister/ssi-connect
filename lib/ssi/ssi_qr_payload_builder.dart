import '../models/dive.dart';
import '../models/dive_type.dart';
import 'ssi_buddy_code.dart';

/// Builds the text payload the official SSI app (com.divessi.ssi) expects
/// when scanning a QR code to import a dive.
///
/// The format is not officially documented. It was first reconstructed from
/// independently-reported example payloads, then confirmed against several
/// real QR codes exported from the SSI app itself. One recreational dive
/// and one XR (extended range) dive from the same logbook:
/// `dive;noid;dive_type:0;divetime:54.0;datetime:202511071050;depth_m:28.0;
/// site:303948;var_watertype_id:5;var_divetype_id:24;var_divetype_id:24;
/// user_master_id:3902893;user_firstname:...;user_lastname:...;
/// user_leader_id:`
/// `dive;noid;dive_type:2;divetime:75.0;datetime:202511060853;depth_m:46.4;
/// site:202305;...` (same tail)
///
/// Key findings from those real examples:
/// - `depth_m` and `divetime` always carry one decimal place, even for
///   whole numbers (`44.0`, not `44`).
/// - `divetime` is dive duration in *minutes*, as a float (so fractional
///   minutes are possible), not whole seconds/minutes.
/// - Field order doesn't matter - one example has `divetime` before
///   `datetime`, the reverse of earlier reference payloads, so this is
///   evidently parsed as an order-independent key/value bag.
/// - Keys may even repeat: SSI's own export emits `var_divetype_id:24`
///   twice. So the parser tolerates duplicates, and nothing here needs to
///   guard against them.
/// - `dive_type` distinguishes recreational (`0`) from XR (`2`).
///
/// The code tables behind the `var_*` fields later turned up in an SSI
/// configuration file, which confirmed `var_watertype_id` (`4` fresh, `5`
/// salt - matching what had been derived by comparing a lake dive against
/// three sea dives) and corrected two `dive_type` values that had been
/// reasoned rather than observed. They are recorded here because knowing a
/// code is not the same as knowing the value:
/// - `deco` - `0` no, `1` yes.
/// - `var_weather_id` - `1` cloudless, `2` cloudy, `3` rainy, `121` snow.
/// - `var_entry_id` - `21` shore, `22` boat, `35` other.
/// - `var_water_body_id` - `13` ocean, `14` river, `15` quarry, `16` lake,
///   `17` indoor, `54` open water.
/// - `var_current_id` - `6` none, `7` light, `8` strong, `9` ripping.
/// - `var_surface_id` - `10` calm, `11` moving, `12` stormy.
///
/// Emitted: `dive_type`, `datetime`, `divetime`, `depth_m`,
/// `var_divetype_id`, plus `watertemp_c`, `var_watertype_id` and `deco`
/// when the source reported them, plus the `user_*` fields when an SSI
/// identity has been scanned for the account.
///
/// Still left out, now for a different reason - not because the code is
/// unknown, but because Garmin never reports the value:
/// - `site` - an SSI dive-site id. Garmin only has GPS coordinates.
/// - `var_weather_id`, `var_entry_id`, `var_water_body_id`,
///   `var_current_id`, `var_surface_id`, `vis_m` - conditions a dive
///   computer doesn't record. Fresh water narrows the water body to lake,
///   river, quarry or indoor, but not to one of them.
/// - `airtemp_c` - Garmin's `maxTemperature` is plausibly the air reading,
///   but that is a guess, and a wrong air temperature is worse than none.
/// - `user_leader_id` - empty in every captured export, so its content is
///   unknown. A divemaster's buddy code carries both a member id
///   (`3154225`) and a `leaderNr` (`110890`), and the field name argues
///   for either: "user id of the leader" reads like the former, "leader
///   number" like the latter. One SSI export of a dive that has a guide
///   recorded would show which - and the app has no way to pick a guide
///   yet anyway.
///
/// An omitted field simply isn't imported; a wrongly guessed one would be
/// silently wrong in the user's logbook, which is the worse failure.
class SsiQrPayloadBuilder {
  const SsiQrPayloadBuilder._();

  /// `dive_type`, from SSI's own code table:
  /// `0` Scuba, `2` Extended Range, `4` Rebreather (self-contained),
  /// `6` Freediving, `8` Rebreather (closed circuit).
  ///
  /// Garmin's `multi_gas_diving` is extended range - a stage or deco
  /// cylinder alongside the back gas is what makes a dive technical - and
  /// `ccr_diving` is by name a closed-circuit rebreather, so it takes `8`.
  ///
  /// Both of those were guesses before the table turned up, and one of them
  /// was wrong: rebreather dives were being filed as extended range, and
  /// freedives as scuba.
  static int _diveTypeFor(DiveType type) => switch (type) {
    DiveType.multiGas => 2,
    DiveType.rebreather => 8,
    DiveType.apnea => 6,
    DiveType.singleGas || DiveType.scuba => 0,
  };

  /// `var_divetype_id`: what the dive was *for*. `23` Education,
  /// `24` Fun Dive, `138` Scientific, `139` Work.
  ///
  /// Garmin has no idea why someone got in the water, so this can't be
  /// derived. It is sent anyway because every captured SSI export of an
  /// ordinary dive carries `24` - that is SSI's own default, so emitting it
  /// reproduces what the app would have written itself rather than
  /// inventing something. A training dive has to be corrected in SSI.
  static const _diveSubTypeFunDive = 24;

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
      'dive_type:${_diveTypeFor(dive.type)}',
      'datetime:${_formatDateTime(dive.dateTime)}',
      'divetime:${_formatFixed(duration.inSeconds / 60.0)}',
      'depth_m:${_formatFixed(maxDepth)}',
    ];

    fields.add('var_divetype_id:$_diveSubTypeFunDive');

    final isDecoDive = dive.isDecoDive;
    if (isDecoDive != null) {
      // SSI: 0 no, 1 yes. Garmin says it outright as `decoDive`.
      fields.add('deco:${isDecoDive ? 1 : 0}');
    }

    final waterType = dive.waterType;
    if (waterType != null) {
      fields.add('var_watertype_id:${waterType.ssiVarId}');
    }

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
