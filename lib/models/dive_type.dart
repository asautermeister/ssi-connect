import '../l10n/app_strings.dart';

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

  /// The type as a heading, for a dive Garmin gave no running number.
  ///
  /// [scuba] is used as it stands: "Gerätetauchgang" and "Scuba dive" are
  /// already complete, and the others are qualifiers that need the noun
  /// after them - "Apnoe" on its own is a discipline, not a dive.
  String title(AppStrings s) => switch (this) {
    DiveType.scuba => s.diveTypeScubaTitle,
    _ => s.diveTypeTitle(label(s)),
  };

  /// Short German label, used as the icon's accessibility description and
  /// in the detail view - the icon never carries the meaning alone.
  /// Takes the texts rather than reading them from a `BuildContext`: an
  /// enum has no context, and passing one in keeps the type free of the
  /// widget layer.
  String label(AppStrings s) => switch (this) {
    DiveType.apnea => s.diveTypeApnea,
    DiveType.singleGas => s.diveTypeSingleGas,
    DiveType.multiGas => s.diveTypeMultiGas,
    DiveType.rebreather => s.diveTypeRebreather,
    DiveType.scuba => s.diveTypeScuba,
  };
}
