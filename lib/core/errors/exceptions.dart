/// Base exception class for data layer
class AppException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  const AppException({
    required this.message,
    this.statusCode,
    this.data,
  });

  @override
  String toString() => 'AppException: $message (statusCode: $statusCode)';
}

/// Server-related exceptions
class ServerException extends AppException {
  const ServerException({
    required super.message,
    super.statusCode,
    super.data,
  });
}

/// Network connectivity exceptions
class NetworkException extends AppException {
  const NetworkException({
    super.message = 'No internet connection',
  });
}

/// Cache-related exceptions
class CacheException extends AppException {
  const CacheException({
    super.message = 'Cache error',
  });
}

/// Authentication exceptions
class AuthException extends AppException {
  const AuthException({
    super.message = 'Authentication failed',
    super.statusCode,
  });
}

/// Unauthorized access exceptions
class UnauthorizedException extends AppException {
  const UnauthorizedException({
    super.message = 'Unauthorized access',
    super.statusCode = 401,
  });
}

/// Permission exceptions
class PermissionException extends AppException {
  const PermissionException({
    super.message = 'Permission denied',
  });
}

/// Location service exceptions
class LocationException extends AppException {
  const LocationException({
    super.message = 'Location service error',
  });
}

/// Timeout exceptions
class TimeoutException extends AppException {
  const TimeoutException({
    super.message = 'Request timed out',
  });
}

/// Platform-specific exceptions (e.g., Android 13+ permission issues)
class PlatformException extends AppException {
  const PlatformException({
    required super.message,
  });
}

