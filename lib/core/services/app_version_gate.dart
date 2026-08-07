import 'package:flutter/foundation.dart';
import 'package:nomowear/core/config/app_build_info.dart';
import 'package:nomowear/core/services/session_cleanup.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Detects APK reinstall/update and forces a clean session.
///
/// Installing a new APK over the existing app keeps SharedPreferences.
/// Comparing [kAppBuildStamp] to the value stored under
/// [SessionCleanup.persistedVersionKey] ensures users must log in again
/// after any version/build change (bump stamp with pubspec on each release).
class AppVersionGate {
  AppVersionGate._();

  /// Returns `true` when a version/build change forced a full session wipe
  /// (caller should treat the user as logged out and show Login).
  static Future<bool> ensureFreshInstallSession() async {
    // Pure Dart stamp — no native package_info_plus plugin required.
    const currentVersion = kAppBuildStamp;

    final prefs = await SharedPreferences.getInstance();
    final storedVersion = prefs.getString(SessionCleanup.persistedVersionKey);

    if (storedVersion == null) {
      // First launch after this feature, or prefs wiped — save and continue.
      // Still wipe session so a first-run after upgrade of old installs is clean
      // when storedVersion was never written but auth tokens remain.
      if (await _hasAnyAuthResidue(prefs)) {
        if (kDebugMode) {
          debugPrint(
            '[AppVersionGate] No stored version but auth residue found — clearing.',
          );
        }
        await SessionCleanup.clearUserSession();
        await prefs.setString(SessionCleanup.persistedVersionKey, currentVersion);
        return true;
      }
      await prefs.setString(SessionCleanup.persistedVersionKey, currentVersion);
      return false;
    }

    if (storedVersion == currentVersion) {
      return false;
    }

    if (kDebugMode) {
      debugPrint(
        '[AppVersionGate] Version changed ($storedVersion → $currentVersion). '
        'Clearing user session.',
      );
    }

    // Wipe previous user's tokens/caches, then persist the new version stamp.
    await SessionCleanup.clearUserSession();
    await prefs.setString(SessionCleanup.persistedVersionKey, currentVersion);
    return true;
  }

  static Future<bool> _hasAnyAuthResidue(SharedPreferences prefs) async {
    final token = prefs.getString('auth_token');
    final pending = prefs.getString('auth_user_token');
    return (token != null && token.isNotEmpty) ||
        (pending != null && pending.isNotEmpty);
  }
}
