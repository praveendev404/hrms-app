import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as permission_handler;
import '../errors/exceptions.dart';

/// Location data model
class LocationData {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  const LocationData({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });

  @override
  String toString() => 'LocationData(lat: $latitude, lon: $longitude, accuracy: $accuracy)';
}

/// Service for handling location-related operations
class LocationService {
  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Request location permission
  Future<bool> requestLocationPermission() async {
    final status = await permission_handler.Permission.location.request();
    return status.isGranted;
  }

  /// Check location permission status
  Future<bool> hasLocationPermission() async {
    final status = await permission_handler.Permission.location.status;
    return status.isGranted;
  }

  /// Get current location
  Future<LocationData> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const LocationException(
          message: 'Location services are disabled. Please enable GPS.',
        );
      }

      // Check permission using both Geolocator and permission_handler for better Android 13+ support
      LocationPermission permission = await Geolocator.checkPermission();
      
      // Also check with permission_handler for Android 13+ compatibility
      final permissionStatus = await permission_handler.Permission.location.status;
      
      if (permission == LocationPermission.denied || permissionStatus.isDenied) {
        // Request permission using both methods for Android 13+ compatibility
        permission = await Geolocator.requestPermission();
        final newStatus = await permission_handler.Permission.location.request();
        
        if (permission == LocationPermission.denied || newStatus.isDenied) {
          throw const PermissionException(
            message: 'Location permission is required for verification. Please grant location access.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever || permissionStatus.isPermanentlyDenied) {
        throw const PermissionException(
          message: 'Location permission is permanently denied. Please enable it in app settings.',
        );
      }

      // Get current position with high accuracy
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: position.timestamp,
      );
    } on PermissionException {
      rethrow;
    } on LocationException {
      rethrow;
    } catch (e) {
      // Provide more specific error messages for common issues
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('permission') || errorString.contains('denied')) {
        throw const PermissionException(
          message: 'Location permission was denied. Please grant location access in app settings.',
        );
      } else if (errorString.contains('timeout') || errorString.contains('timed out')) {
        throw const LocationException(
          message: 'Location request timed out. Please ensure GPS is enabled and try again.',
        );
      } else if (errorString.contains('unavailable') || errorString.contains('service')) {
        throw const LocationException(
          message: 'Location service is unavailable. Please check your GPS settings.',
        );
      } else {
        throw LocationException(
          message: 'Failed to get location. Please ensure GPS is enabled and try again.',
        );
      }
    }
  }

  /// Get location stream for continuous updates
  Stream<LocationData> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).map((position) => LocationData(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          timestamp: position.timestamp,
        ),);
  }

  /// Calculate distance between two points in meters
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Open location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Open app settings
  Future<bool> openAppSettings() async {
    return await permission_handler.openAppSettings();
  }
}

