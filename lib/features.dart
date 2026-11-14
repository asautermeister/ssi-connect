/// Functions that are built but not yet shown.
///
/// Off in every release build. Switched on for a run with
/// `flutter run --dart-define=PERSONAL_API=true`.
///
/// Only the entry points are switched off, not the code behind them. An
/// account that already carries a key still gets its own expiry handling,
/// because that is the only way such an account can recover.
abstract final class Features {
  /// The Garmin Personal API key as an alternative to signing in. Hidden
  /// until it has run on a real device and the licence terms have been read
  /// (see BACKLOG.md, "Personal API").
  static const personalApi = bool.fromEnvironment('PERSONAL_API');
}
