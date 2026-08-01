/// The kind of dive, as far as the list needs to distinguish it.
///
/// Garmin exposes this as an `activityType.typeKey` on each activity (with
/// a numeric `typeId` alongside - 148 is `apnea_diving`, for instance). We
/// match on the key rather than the id: the keys are stable strings that
/// say what they mean, and an unknown one degrades to [scuba] instead of
/// mapping to the wrong picture.
enum DiveType {
  /// Freediving, including apnea hunting.
  apnea,

  /// One cylinder, a single breathing gas.
  singleGas,

  /// More than one gas - a stage or deco cylinder alongside the back gas.
  multiGas,

  /// Closed-circuit rebreather.
  rebreather,

  /// Open-circuit scuba where Garmin didn't say which gas setup was used.
  scuba;

  /// Maps a Garmin `typeKey`. Unrecognised and missing keys fall back to
  /// [scuba], since every dive type we query for is at least a dive.
  static DiveType fromGarminTypeKey(String? typeKey) {
    switch (typeKey) {
      case 'apnea_diving':
      case 'apnea_hunting':
        return DiveType.apnea;
      case 'single_gas_diving':
        return DiveType.singleGas;
      case 'multi_gas_diving':
        return DiveType.multiGas;
      case 'ccr_diving':
        return DiveType.rebreather;
      default:
        return DiveType.scuba;
    }
  }

  /// Short German label, used as the icon's accessibility description and
  /// in the detail view - the icon never carries the meaning alone.
  String get label => switch (this) {
    DiveType.apnea => 'Apnoe',
    DiveType.singleGas => 'Single Gas',
    DiveType.multiGas => 'Multi Gas',
    DiveType.rebreather => 'Rebreather (CCR)',
    DiveType.scuba => 'Gerätetauchgang',
  };
}
