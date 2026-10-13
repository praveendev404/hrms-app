import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// Secure storage service for sensitive data
class StorageService {
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _preferences;

  StorageService({
    required FlutterSecureStorage secureStorage,
    required SharedPreferences preferences,
  })  : _secureStorage = secureStorage,
        _preferences = preferences;

  // ============ Secure Storage (for sensitive data) ============

  /// Save auth token securely
  Future<void> saveAuthToken(String token) async {
    await _secureStorage.write(key: AppConstants.authTokenKey, value: token);
  }

  /// Get auth token
  Future<String?> getAuthToken() async {
    return await _secureStorage.read(key: AppConstants.authTokenKey);
  }

  /// Save refresh token securely
  Future<void> saveRefreshToken(String token) async {
    await _secureStorage.write(key: AppConstants.refreshTokenKey, value: token);
  }

  /// Get refresh token
  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: AppConstants.refreshTokenKey);
  }

  /// Save user ID securely
  Future<void> saveUserId(String userId) async {
    await _secureStorage.write(key: AppConstants.userIdKey, value: userId);
  }

  /// Get user ID
  Future<String?> getUserId() async {
    return await _secureStorage.read(key: AppConstants.userIdKey);
  }

  /// Clear all secure storage
  Future<void> clearSecureStorage() async {
    await _secureStorage.deleteAll();
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }

  // ============ Shared Preferences (for non-sensitive data) ============

  /// Save theme mode preference
  Future<void> saveThemeMode(bool isDark) async {
    await _preferences.setBool('isDarkMode', isDark);
  }

  /// Get theme mode preference
  bool getThemeMode() {
    return _preferences.getBool('isDarkMode') ?? false;
  }

  /// Save first launch flag
  Future<void> setFirstLaunchComplete() async {
    await _preferences.setBool('isFirstLaunch', false);
  }

  /// Check if first launch
  bool isFirstLaunch() {
    return _preferences.getBool('isFirstLaunch') ?? true;
  }

  /// Clear all preferences
  Future<void> clearPreferences() async {
    await _preferences.clear();
  }

  /// Clear all data (logout)
  Future<void> clearAll() async {
    await clearSecureStorage();
    await clearPreferences();
  }
}

