/// Keep in sync with `version:` in pubspec.yaml (e.g. `1.0.0+2`).
///
/// Used by [AppVersionGate] instead of package_info_plus so Android builds
/// do not depend on the native PackageInfoPlugin (which was failing to compile).
/// Bump this whenever you bump the pubspec version/build for a new APK.
const String kAppBuildStamp = '1.0.0+2';
