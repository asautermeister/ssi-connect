/// Facts about the app itself, for the info screen.
///
/// [version] is kept here rather than read at runtime with
/// `package_info_plus`: that plugin skips its own Kotlin setup on AGP 9,
/// which is exactly the breakage this project already hit once with
/// `file_picker`, and there is no fixed release. A constant costs nothing
/// and cannot fail to build.
///
/// It can drift from `pubspec.yaml` - so a test reads the pubspec and
/// fails if the two ever disagree.
class AppInfo {
  const AppInfo._();

  /// Must match `version:` in pubspec.yaml, build number included.
  static const version = '1.2.0+5';

  static const repositoryUrl = 'https://github.com/asautermeister/ssi-connect';

  /// Short version without the build number, for places where the build
  /// number is noise.
  static String get versionName => version.split('+').first;
}
