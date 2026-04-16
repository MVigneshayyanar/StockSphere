/// Stub file for web platform
/// This file provides stub implementations for packages that don't support web

// Stub for permission_handler
class Permission {
  static final Permission bluetooth = Permission._();
  static final Permission bluetoothScan = Permission._();
  static final Permission bluetoothConnect = Permission._();
  static final Permission location = Permission._();

  Permission._();

  Future<PermissionStatus> request() async => PermissionStatus.denied;
}

class PermissionStatus {
  static const PermissionStatus denied = PermissionStatus._('denied');
  static const PermissionStatus granted = PermissionStatus._('granted');

  final String _value;
  const PermissionStatus._(this._value);

  bool get isGranted => _value == 'granted';
}

// Stub for flutter_blue_plus
class FlutterBluePlus {
  static Future<void> turnOn() async {}
}

