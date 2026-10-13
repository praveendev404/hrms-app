import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/services/camera_service.dart';
import '../../core/services/device_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/storage_service.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth_usecases.dart';
import '../../main.dart';
import '../screens/login/login_screen.dart';

// ============ Core Services ============

/// Shared preferences provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in main');
});

/// Secure storage provider
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
});

/// Storage service provider
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(
    secureStorage: ref.watch(secureStorageProvider),
    preferences: ref.watch(sharedPreferencesProvider),
  );
});

/// API client provider
final apiClientProvider = Provider<ApiClient>((ref) {
  final apiClient = ApiClient();
  final storageService = ref.watch(storageServiceProvider);
  
  // Set up handler for 401 unauthorized responses
  apiClient.setUnauthorizedCallback(() async {
    // Clear auth tokens
    apiClient.clearAuthToken();
    await storageService.clearSecureStorage();
    
    // Navigate to login screen
    final context = navigatorKey.currentContext;
    if (context != null && navigatorKey.currentState != null) {
      navigatorKey.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  });
  
  return apiClient;
});

/// Location service provider
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// Camera service provider
final cameraServiceProvider = Provider<CameraService>((ref) {
  return CameraService(locationService: ref.watch(locationServiceProvider));
});

/// Device service provider
final deviceServiceProvider = Provider<DeviceService>((ref) {
  return DeviceService(
    preferences: ref.watch(sharedPreferencesProvider),
  );
});

/// Device info provider - async provider to get device information
final deviceInfoProvider = FutureProvider<DeviceInfo>((ref) async {
  final deviceService = ref.watch(deviceServiceProvider);
  return await deviceService.getDeviceInfo();
});

// ============ Data Sources ============

/// Auth remote data source provider
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl(apiClient: ref.watch(apiClientProvider));
});

// ============ Repositories ============

/// Auth repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    storageService: ref.watch(storageServiceProvider),
    apiClient: ref.watch(apiClientProvider),
  );
});

// ============ Use Cases ============

/// Login use case provider
final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return LoginUseCase(ref.watch(authRepositoryProvider));
});

/// Logout use case provider
final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  return LogoutUseCase(ref.watch(authRepositoryProvider));
});

/// Check login status use case provider
final checkLoginStatusUseCaseProvider = Provider<CheckLoginStatusUseCase>((ref) {
  return CheckLoginStatusUseCase(ref.watch(authRepositoryProvider));
});

/// Refresh token use case provider
final refreshTokenUseCaseProvider = Provider<RefreshTokenUseCase>((ref) {
  return RefreshTokenUseCase(ref.watch(authRepositoryProvider));
});

/// Get user info use case provider
final getUserInfoUseCaseProvider = Provider<GetUserInfoUseCase>((ref) {
  return GetUserInfoUseCase(ref.watch(authRepositoryProvider));
});

/// Change password use case provider
final changePasswordUseCaseProvider = Provider<ChangePasswordUseCase>((ref) {
  return ChangePasswordUseCase(ref.watch(authRepositoryProvider));
});

