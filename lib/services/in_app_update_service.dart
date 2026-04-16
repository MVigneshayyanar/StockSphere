import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Service to handle in-app updates for Android
/// Uses Google Play In-App Updates API
class InAppUpdateService {
  /// Check if an update is available and show update UI
  static Future<void> checkForUpdate() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      // In-app updates only work on Android
      return;
    }

    try {
      // Check if update is available
      final AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        // If immediate update is available, perform it
        if (updateInfo.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        }
        // If flexible update is available, start it
        else if (updateInfo.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          // Listen for update download completion
          InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (e) {
      debugPrint('Error checking for update: $e');
    }
  }

  /// Check for flexible update only
  static Future<void> checkForFlexibleUpdate() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      final AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        if (updateInfo.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          // After download completes, show snackbar to install
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (e) {
      debugPrint('Error checking for flexible update: $e');
    }
  }

  /// Check for immediate update only (forces user to update)
  static Future<void> checkForImmediateUpdate() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      final AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        if (updateInfo.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        }
      }
    } catch (e) {
      debugPrint('Error checking for immediate update: $e');
    }
  }
}

