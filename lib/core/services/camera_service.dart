import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../errors/exceptions.dart';
import 'location_service.dart';

/// Photo data model with metadata
class PhotoData {
  final File file;
  final double latitude;
  final double longitude;
  final String timestamp;

  const PhotoData({
    required this.file,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  @override
  String toString() => 'PhotoData(file: ${file.path}, lat: $latitude, lon: $longitude)';
}

/// Service for handling camera and photo operations
class CameraService {
  final ImagePicker _imagePicker;
  final LocationService _locationService;

  CameraService({
    ImagePicker? imagePicker,
    required LocationService locationService,
  })  : _imagePicker = imagePicker ?? ImagePicker(),
        _locationService = locationService;

  /// Request camera permission
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Check camera permission status
  Future<bool> hasCameraPermission() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// Capture photo from camera with location metadata
  Future<PhotoData?> capturePhoto() async {
    // Check and request camera permission
    final hasPermission = await hasCameraPermission();
    if (!hasPermission) {
      final granted = await requestCameraPermission();
      if (!granted) {
        throw const PermissionException(
          message: 'Camera permission is required to capture photos.',
        );
      }
    }

    try {
      // Get current location for metadata
      final location = await _locationService.getCurrentLocation();

      // Capture photo
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 85, // Good quality with reasonable file size
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image == null) {
        return null; // User cancelled
      }

      return PhotoData(
        file: File(image.path),
        latitude: location.latitude,
        longitude: location.longitude,
        timestamp: DateTime.now().toUtc().toIso8601String(),
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(
        message: 'Failed to capture photo: ${e.toString()}',
      );
    }
  }

  /// Pick image from gallery (for testing purposes only)
  Future<File?> pickFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image == null) return null;
      return File(image.path);
    } catch (e) {
      throw ServerException(
        message: 'Failed to pick image: ${e.toString()}',
      );
    }
  }

  /// Delete photo file
  Future<void> deletePhoto(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Silently fail - not critical
    }
  }
}

