import '../l10n/app_strings.dart';

/// Fresh or salt water. The one dive condition that isn't a matter of
/// judgement - the dive computer needs it to compute depth at all, so it is
/// recorded rather than remembered.
///
/// Named `DiveWaterType` and not `WaterType` because `fit_tool` exports a
/// `WaterType` of its own; keeping the names apart avoids an import alias
/// in the FIT reader.
enum DiveWaterType {
  fresh,
  salt;

  /// SSI's `var_watertype_id`, read off real exports from one logbook: a
  /// lake dive carried `4`, three sea dives `5`. The remaining values of
  /// that code table (brackish and whatever else SSI offers) are unknown,
  /// so nothing else is ever emitted.
  int get ssiVarId => switch (this) {
    DiveWaterType.fresh => 4,
    DiveWaterType.salt => 5,
  };

  String label(AppStrings s) => switch (this) {
    DiveWaterType.fresh => s.waterFresh,
    DiveWaterType.salt => s.waterSalt,
  };

  /// Classifies a water density in kg/m³: fresh water is about 1000,
  /// sea water about 1025.
  ///
  /// Density is used rather than any vendor's "water type" code because it
  /// is a physical quantity that cannot mean something else. Values outside
  /// a plausible range are rejected as null - a field that turns out to
  /// hold something other than kg/m³ then leaves the water type unset
  /// instead of guessing at it.
  static DiveWaterType? fromDensity(num? kgPerCubicMetre) {
    if (kgPerCubicMetre == null) return null;
    if (kgPerCubicMetre < 950 || kgPerCubicMetre > 1100) return null;
    // Halfway between the two, so ordinary brackish water still lands on
    // the side it is closer to.
    return kgPerCubicMetre < 1012 ? DiveWaterType.fresh : DiveWaterType.salt;
  }

  /// Accepts a spelled-out water type (`"fresh"`, `"salt"`). Only strings:
  /// a numeric code would need a code table we haven't verified.
  static DiveWaterType? fromName(String? name) =>
      switch (name?.trim().toLowerCase()) {
        'fresh' || 'freshwater' || 'fresh_water' => DiveWaterType.fresh,
        'salt' || 'saltwater' || 'salt_water' || 'sea' => DiveWaterType.salt,
        _ => null,
      };
}
