import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

/// Centralized permission manager that requests permissions lazily
/// Only when the user actually needs them for a specific feature
class PermissionManager {
  static bool _bluetoothPermissionsRequested = false;
  static bool _contactsPermissionRequested = false;
  static bool _cameraPermissionRequested = false;
  static bool _storagePermissionRequested = false;

  /// Request Bluetooth permissions (only when user tries to connect to printer)
  static Future<bool> requestBluetoothPermissions(BuildContext context) async {
    if (_bluetoothPermissionsRequested) {
      // Check if already granted
      final scanStatus = await Permission.bluetoothScan.status;
      final connectStatus = await Permission.bluetoothConnect.status;
      final locationStatus = await Permission.location.status;

      if (scanStatus.isGranted && connectStatus.isGranted && locationStatus.isGranted) {
        return true;
      }
    }

    try {
      // Show explanation dialog first
      final shouldRequest = await _showPermissionDialog(
        context,
        title: 'Bluetooth Permission Required',
        message: 'This app needs Bluetooth and Location permissions to connect to your Bluetooth printer. Grant permission?',
      );

      if (!shouldRequest) return false;

      _bluetoothPermissionsRequested = true;

      // Request Bluetooth permissions (Android 12+)
      final bluetoothStatus = await Permission.bluetooth.request();
      final scanStatus = await Permission.bluetoothScan.request();
      final connectStatus = await Permission.bluetoothConnect.request();

      // Request location permission (required for Bluetooth scanning on Android)
      final locationStatus = await Permission.location.request();

      // Check if all permissions granted
      if (bluetoothStatus.isGranted &&
          scanStatus.isGranted &&
          connectStatus.isGranted &&
          locationStatus.isGranted) {

        // Try to enable Bluetooth
        try {
          await FlutterBluePlus.turnOn();
          debugPrint('✅ Bluetooth enabled successfully');
          return true;
        } catch (e) {
          debugPrint('⚠️ Could not auto-enable Bluetooth: $e');
          // Still return true if permissions granted
          return true;
        }
      } else {
        // Show settings dialog if permission denied
        if (bluetoothStatus.isPermanentlyDenied ||
            scanStatus.isPermanentlyDenied ||
            connectStatus.isPermanentlyDenied ||
            locationStatus.isPermanentlyDenied) {
          await _showSettingsDialog(context, 'Bluetooth');
        }
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error requesting Bluetooth permissions: $e');
      return false;
    }
  }

  /// Request Contacts permission (only when user tries to import contacts)
  static Future<bool> requestContactsPermission(BuildContext context) async {
    if (_contactsPermissionRequested) {
      // Check if already granted
      final status = await Permission.contacts.status;
      if (status.isGranted) return true;
    }

    try {
      // Show explanation dialog first
      final shouldRequest = await _showPermissionDialog(
        context,
        title: 'Contacts Permission Required',
        message: 'This app needs access to your contacts to import customer information. Grant permission?',
      );

      if (!shouldRequest) return false;

      _contactsPermissionRequested = true;

      // Request using flutter_contacts package
      final granted = await FlutterContacts.requestPermission();

      if (!granted) {
        final status = await Permission.contacts.status;
        if (status.isPermanentlyDenied) {
          await _showSettingsDialog(context, 'Contacts');
        }
      }

      return granted;
    } catch (e) {
      debugPrint('❌ Error requesting Contacts permission: $e');
      return false;
    }
  }

  /// Request Camera permission (only when user tries to scan QR or take photo)
  static Future<bool> requestCameraPermission(BuildContext context) async {
    if (_cameraPermissionRequested) {
      final status = await Permission.camera.status;
      if (status.isGranted) return true;
    }

    try {
      // Show explanation dialog first
      final shouldRequest = await _showPermissionDialog(
        context,
        title: 'Camera Permission Required',
        message: 'This app needs camera access to scan QR codes or take photos. Grant permission?',
      );

      if (!shouldRequest) return false;

      _cameraPermissionRequested = true;

      final status = await Permission.camera.request();

      if (status.isGranted) {
        return true;
      } else if (status.isPermanentlyDenied) {
        await _showSettingsDialog(context, 'Camera');
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error requesting Camera permission: $e');
      return false;
    }
  }

  /// Request Storage permission (only when user tries to pick image/file)
  static Future<bool> requestStoragePermission(BuildContext context) async {
    if (_storagePermissionRequested) {
      final status = await Permission.storage.status;
      if (status.isGranted) return true;
    }

    try {
      // Show explanation dialog first
      final shouldRequest = await _showPermissionDialog(
        context,
        title: 'Storage Permission Required',
        message: 'This app needs storage access to select photos and files. Grant permission?',
      );

      if (!shouldRequest) return false;

      _storagePermissionRequested = true;

      final status = await Permission.storage.request();

      if (status.isGranted) {
        return true;
      } else if (status.isPermanentlyDenied) {
        await _showSettingsDialog(context, 'Storage');
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error requesting Storage permission: $e');
      return false;
    }
  }

  /// Show permission explanation dialog before requesting
  static Future<bool> _showPermissionDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF2F7CF6)),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Deny'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F7CF6),
            ),
            child: const Text('Allow', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Show settings dialog when permission is permanently denied
  static Future<void> _showSettingsDialog(BuildContext context, String permissionName) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permissionName Permission Denied'),
        content: Text(
          'You have permanently denied $permissionName permission. '
          'Please enable it from Settings to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F7CF6),
            ),
            child: const Text('Open Settings', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Reset permission request flags (useful for testing)
  static void resetPermissionFlags() {
    _bluetoothPermissionsRequested = false;
    _contactsPermissionRequested = false;
    _cameraPermissionRequested = false;
    _storagePermissionRequested = false;
  }
}

