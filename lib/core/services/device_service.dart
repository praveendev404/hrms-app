import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';

/// Service to get device information for push notifications
class DeviceService {
  final DeviceInfoPlugin _deviceInfo;
  final SharedPreferences? _preferences;

  DeviceService({
    DeviceInfoPlugin? deviceInfo,
    SharedPreferences? preferences,
  })  : _deviceInfo = deviceInfo ?? DeviceInfoPlugin(),
        _preferences = preferences;

  /// Get the device type ID based on platform
  /// Returns 1 for iOS, 2 for Android, 3 for Web
  int getDeviceTypeId() {
    // Check for web first (kIsWeb works everywhere)
    if (kIsWeb) {
      return AppConstants.deviceTypeWeb;
    }
    
    // For non-web platforms, check the target platform
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return AppConstants.deviceTypeIos;
      case TargetPlatform.android:
        return AppConstants.deviceTypeAndroid;
      default:
        // Default to Android for other platforms (Windows, Linux, macOS)
        return AppConstants.deviceTypeAndroid;
    }
  }

  /// Get the unique device identifier for push notifications
  /// For iOS: identifierForVendor
  /// For Android: androidId (with fallback for Android 13+)
  /// For Web: generates and persists a UUID
  Future<String?> getDeviceId() async {
    try {
      // Handle web platform
      if (kIsWeb) {
        return await _getOrCreateWebDeviceId();
      }

      // Handle native platforms
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
          final iosInfo = await _deviceInfo.iosInfo;
          return iosInfo.identifierForVendor;
        case TargetPlatform.android:
          try {
            final androidInfo = await _deviceInfo.androidInfo;
            // Android 13+ may return empty ID, use fallback if needed
            final deviceId = androidInfo.id;
            if (deviceId.isNotEmpty) {
              return deviceId;
            }
            // Fallback to persistent UUID for Android 13+
            return await _getOrCreateAndroidDeviceId();
          } catch (e) {
            if (kDebugMode) {
              print('Error getting Android device ID: $e');
            }
            // Fallback to persistent UUID
            return await _getOrCreateAndroidDeviceId();
          }
        default:
          // For other platforms, generate a UUID
          return await _getOrCreateWebDeviceId();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting device ID: $e');
      }
      // Fallback: generate a random UUID
      return const Uuid().v4();
    }
  }

  /// Get or create a persistent device ID for Android (fallback for Android 13+)
  Future<String> _getOrCreateAndroidDeviceId() async {
    const storageKey = 'android_device_id';
    
    // Try to get from SharedPreferences if available
    if (_preferences != null) {
      final existingId = _preferences.getString(storageKey);
      if (existingId != null && existingId.isNotEmpty) {
        return existingId;
      }
      
      // Generate new UUID and persist it
      final newId = const Uuid().v4();
      await _preferences.setString(storageKey, newId);
      return newId;
    }
    
    // If no preferences available, just generate a UUID
    return const Uuid().v4();
  }

  /// Get or create a persistent device ID for web/desktop
  Future<String> _getOrCreateWebDeviceId() async {
    const storageKey = 'web_device_id';
    
    // Try to get from SharedPreferences if available
    if (_preferences != null) {
      final existingId = _preferences.getString(storageKey);
      if (existingId != null && existingId.isNotEmpty) {
        return existingId;
      }
      
      // Generate new UUID and persist it
      final newId = const Uuid().v4();
      await _preferences.setString(storageKey, newId);
      return newId;
    }
    
    // If no preferences available, just generate a UUID
    return const Uuid().v4();
  }

  /// Get device name/model for debugging purposes
  Future<String> getDeviceName() async {
    try {
      if (kIsWeb) {
        final webInfo = await _deviceInfo.webBrowserInfo;
        return '${webInfo.browserName.name} on ${webInfo.platform ?? 'Web'}';
      }

      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
          final iosInfo = await _deviceInfo.iosInfo;
          return '${iosInfo.name} (${iosInfo.model})';
        case TargetPlatform.android:
          final androidInfo = await _deviceInfo.androidInfo;
          return '${androidInfo.brand} ${androidInfo.model}';
        case TargetPlatform.windows:
          final windowsInfo = await _deviceInfo.windowsInfo;
          return windowsInfo.computerName;
        case TargetPlatform.macOS:
          final macInfo = await _deviceInfo.macOsInfo;
          return '${macInfo.computerName} (${macInfo.model})';
        case TargetPlatform.linux:
          final linuxInfo = await _deviceInfo.linuxInfo;
          return linuxInfo.prettyName;
        default:
          return 'Unknown Device';
      }
    } catch (e) {
      return 'Unknown Device';
    }
  }

  /// Get all device info for login
  Future<DeviceInfo> getDeviceInfo() async {
    try {
      final deviceId = await getDeviceId();
      final deviceTypeId = getDeviceTypeId();
      final deviceName = await getDeviceName();

      return DeviceInfo(
        deviceId: deviceId,
        deviceTypeId: deviceTypeId,
        deviceName: deviceName,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error getting device info: $e');
      }
      // Return fallback device info
      return DeviceInfo(
        deviceId: const Uuid().v4(),
        deviceTypeId: getDeviceTypeId(),
        deviceName: 'Unknown Device',
      );
    }
  }
}

/// Device information model
class DeviceInfo {
  final String? deviceId;
  final int deviceTypeId;
  final String deviceName;

  const DeviceInfo({
    this.deviceId,
    required this.deviceTypeId,
    required this.deviceName,
  });

  /// Check if device is iOS
  bool get isIos => deviceTypeId == AppConstants.deviceTypeIos;

  /// Check if device is Android
  bool get isAndroid => deviceTypeId == AppConstants.deviceTypeAndroid;
}

