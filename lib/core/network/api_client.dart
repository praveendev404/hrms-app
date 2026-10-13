import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';
import '../errors/exceptions.dart';
import '../services/reminder_service.dart';
import 'response_cache.dart';
import 'package:flutter/material.dart';

/// Dio API client with interceptors and error handling
class ApiClient {
  late final Dio _dio;
  String? _authToken;
  VoidCallback? _onUnauthorized;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: AppConstants.connectionTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _setupInterceptors();
  }

  /// Setup request/response interceptors
  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Add auth token if available
          if (_authToken != null) {
            options.headers['Authorization'] = 'Bearer $_authToken';
          }

          if (kDebugMode) {
            final fullUrl = '${options.baseUrl}${options.path}';
            print('REQUEST[${options.method}] => FULL URL: $fullUrl');
            print('PATH: ${options.path}');
            print('Base URL: ${options.baseUrl}');
            print('Headers: ${options.headers}');
            if (options.queryParameters.isNotEmpty) {
              print('Query Parameters: ${options.queryParameters}');
            }
            if (options.data != null) {
              print('Body: ${options.data}');
            }
          }

          return handler.next(options);
        },
        onResponse: (response, handler) {
          // Keep a copy of read calls for offline use; a live answer means we are online.
          if (response.statusCode == 200 && ResponseCache.isCacheable(response.requestOptions)) {
            ResponseCache.servingSavedData.value = null;
            ResponseCache.save(response);
          }
          if (kDebugMode) {
            print('RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}');
            print('Data: ${response.data}');
          }

          return handler.next(response);
        },
        onError: (error, handler) async {
          // No signal: answer a read call from the saved copy, if there is one.
          if (ResponseCache.isConnectionProblem(error) && ResponseCache.isCacheable(error.requestOptions)) {
            final saved = await ResponseCache.load(error.requestOptions);
            if (saved != null) return handler.resolve(saved);
          }
          if (kDebugMode) {
            print('ERROR[${error.response?.statusCode ?? 'NO_RESPONSE'}] => PATH: ${error.requestOptions.path}');
            print('Error Type: ${error.type}');
            print('Message: ${error.message ?? 'No message'}');
            print('Error Object: ${error.error}');
            if (error.response != null) {
              print('Response Data: ${error.response?.data}');
              print('Response Headers: ${error.response?.headers}');
            }
            if (error.type == DioExceptionType.unknown) {
              print('Unknown Error Details: ${error.error}');
            }
          }

          return handler.next(error);
        },
      ),
    );
  }

  /// Set authentication token
  void setAuthToken(String token) {
    _authToken = token;
  }

  /// Clear authentication token
  void clearAuthToken() {
    ResponseCache.clear(); // saved data belongs to the signed-in user
    ReminderService.stopAll(); // and so do reminders and background alerts
    _authToken = null;
  }

  /// Set callback for handling 401 unauthorized responses
  void setUnauthorizedCallback(VoidCallback callback) {
    _onUnauthorized = callback;
  }

  /// GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Upload file with multipart form data
  Future<Response<T>> uploadFile<T>(
    String path, {
    required File file,
    required String fieldName,
    Map<String, dynamic>? additionalData,
    void Function(int, int)? onSendProgress,
  }) async {
    try {
      final fileName = file.path.split('/').last;
      final formData = FormData.fromMap({
        fieldName: await MultipartFile.fromFile(
          file.path,
          filename: fileName,
        ),
        ...?additionalData,
      });

      return await _dio.post<T>(
        path,
        data: formData,
        onSendProgress: onSendProgress,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Upload multiple files with JSON model in form data
  /// This sends a "model" field with JSON string and multiple files
  Future<Response<T>> uploadFilesWithModel<T>(
    String path, {
    required String modelJson,
    List<File>? files,
    void Function(int, int)? onSendProgress,
  }) async {
    try {
      final Map<String, dynamic> formMap = {
        'model': modelJson,
      };

      // Add files if provided
      if (files != null && files.isNotEmpty) {
        for (int i = 0; i < files.length; i++) {
          final file = files[i];
          final fileName = file.path.split(Platform.pathSeparator).last;
          // Send files with empty field names to match cURL pattern: =@"/path/to/file"
          formMap[''] = await MultipartFile.fromFile(
            file.path,
            filename: fileName,
          );
        }
      }

      final formData = FormData.fromMap(formMap);

      return await _dio.post<T>(
        path,
        data: formData,
        onSendProgress: onSendProgress,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Upload files with specific types (house, street_name, landmark, other) along with a JSON model
  Future<Response<T>> uploadFilesWithTypedModel<T>(
    String path, {
    required String modelJson,
    List<Map<String, dynamic>>? filesWithTypes,
    void Function(int, int)? onSendProgress,
  }) async {
    try {
      final Map<String, dynamic> formMap = {
        'model': modelJson,
      };

      // Add typed files if provided
      // Expected format: [{'file': File, 'type': 'house'|'street_name'|'landmark'|'other'}]
      if (filesWithTypes != null && filesWithTypes.isNotEmpty) {
        for (int i = 0; i < filesWithTypes.length; i++) {
          final fileData = filesWithTypes[i];
          final file = fileData['file'] as File;
          final type = fileData['type'] as String;
          final fileName = file.path.split(Platform.pathSeparator).last;
          
          // Use type as field name prefix: housePhoto, streetNamePhoto, landmarkPhoto, otherPhoto0, otherPhoto1, etc.
          String fieldName;
          if (type == 'house') {
            fieldName = 'housePhoto';
          } else if (type == 'street_name') {
            fieldName = 'streetNamePhoto';
          } else if (type == 'landmark') {
            fieldName = 'landmarkPhoto';
          } else {
            // For 'other' type, use index to allow multiple
            final otherIndex = filesWithTypes
                .take(i + 1)
                .where((item) => item['type'] == 'other')
                .length - 1;
            fieldName = 'otherPhoto$otherIndex';
          }
          
          formMap[fieldName] = await MultipartFile.fromFile(
            file.path,
            filename: fileName,
          );
        }
      }

      final formData = FormData.fromMap(formMap);

      return await _dio.post<T>(
        path,
        data: formData,
        onSendProgress: onSendProgress,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Upload files with meaningful names based on photo type
  Future<Response<T>> uploadFilesWithTypedNames<T>(
    String path, {
    required String modelJson,
    List<Map<String, dynamic>>? filesWithTypes,
    void Function(int, int)? onSendProgress,
  }) async {
    try {
      final Map<String, dynamic> formMap = {
        'model': modelJson,
      };

      // Add files with meaningful names based on type
      if (filesWithTypes != null && filesWithTypes.isNotEmpty) {
        int otherPhotoCount = 1;
        int fileIndex = 0;
        
        for (var fileData in filesWithTypes) {
          final file = fileData['file'] as File;
          final type = fileData['type'] as String;
          final originalFileName = file.path.split(Platform.pathSeparator).last;
          final extension = originalFileName.contains('.') 
              ? originalFileName.substring(originalFileName.lastIndexOf('.'))
              : '.jpg';
          
          // Generate meaningful filename based on type
          String meaningfulFileName;
          if (type == 'house') {
            meaningfulFileName = 'house_photo$extension';
          } else if (type == 'street_name') {
            meaningfulFileName = 'street_photo$extension';
          } else if (type == 'landmark') {
            meaningfulFileName = 'landmark_photo$extension';
          } else {
            meaningfulFileName = 'other_photo_$otherPhotoCount$extension';
            otherPhotoCount++;
          }
          
          // Use unique field name for each file (empty string doesn't work for multiple files)
          // .NET will read all files from Request.Form.Files
          formMap['file$fileIndex'] = await MultipartFile.fromFile(
            file.path,
            filename: meaningfulFileName,
          );
          fileIndex++;
        }
      }

      final formData = FormData.fromMap(formMap);

      return await _dio.post<T>(
        path,
        data: formData,
        onSendProgress: onSendProgress,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Handle Dio errors and convert to app exceptions
  AppException _handleDioError(DioException error) {
    // First, try to extract error message from response data if available
    String? responseMessage;
    if (error.response != null && error.response?.data != null) {
      final data = error.response!.data;
      if (data is Map<String, dynamic>) {
        responseMessage = data['message'] ?? 
                         data['error'] ?? 
                         data['errorMessage'] ??
                         data['title'];
      } else if (data is String) {
        responseMessage = data;
      }
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutException(
          message: responseMessage ?? 'Connection timed out. Please try again.',
        );

      case DioExceptionType.badResponse:
        return _handleBadResponse(error.response);

      case DioExceptionType.cancel:
        return ServerException(
          message: responseMessage ?? 'Request was cancelled.',
        );

      case DioExceptionType.connectionError:
        // Check if there's a response with error details
        if (responseMessage != null) {
          return NetworkException(
            message: responseMessage,
          );
        }
        return const NetworkException(
          message: 'No internet connection. Please check your network.',
        );

      case DioExceptionType.unknown:
        // Check for specific error types
        if (error.error is SocketException) {
          return const NetworkException(
            message: 'No internet connection. Please check your network.',
          );
        }
        
        // Use response message if available
        if (responseMessage != null && responseMessage.isNotEmpty) {
          return ServerException(
            message: responseMessage,
            statusCode: error.response?.statusCode,
            data: error.response?.data,
          );
        }
        
        // Provide more specific error messages from error message
        final errorMessage = error.message ?? '';
        if (errorMessage.contains('Failed host lookup') || 
            errorMessage.contains('Network is unreachable') ||
            errorMessage.contains('Unable to resolve host')) {
          return const NetworkException(
            message: 'Network connection failed. Please check your internet connection.',
          );
        }
        // Check for SSL/Certificate errors
        final errorString = error.error?.toString() ?? '';
        if (errorMessage.contains('HandshakeException') || 
            errorMessage.contains('Certificate') ||
            errorMessage.contains('TLS') ||
            errorMessage.contains('SSL') ||
            errorString.contains('CERTIFICATE_VERIFY_FAILED') ||
            errorString.contains('HandshakeException')) {
          return ServerException(
            message: 'SSL certificate verification failed. Please contact support if this issue persists.',
            statusCode: error.response?.statusCode,
          );
        }
        
        // Check error object for more details
//        final errorString = error.error?.toString() ?? '';
        if (errorString.isNotEmpty && !errorString.contains('null')) {
          // Check for common error patterns
          if (errorString.contains('SocketException') ||
              errorString.contains('Connection refused') ||
              errorString.contains('Connection timed out')) {
            return const NetworkException(
              message: 'Unable to connect to server. Please check your internet connection.',
            );
          }
          return ServerException(
            message: 'Connection error: $errorString',
            statusCode: error.response?.statusCode,
          );
        }
        
        // If everything is null/empty, provide a generic but helpful message
        if (error.response == null && errorMessage.isEmpty && errorString.isEmpty) {
          return const NetworkException(
            message: 'Unable to connect to server. Please check your internet connection and try again.',
          );
        }
        
        return ServerException(
          message: errorMessage.isNotEmpty 
              ? 'Connection error: $errorMessage' 
              : 'An unexpected error occurred. Please check your connection and try again.',
          statusCode: error.response?.statusCode,
        );

      default:
        // Use response message if available
        if (responseMessage != null && responseMessage.isNotEmpty) {
          return ServerException(
            message: responseMessage,
            statusCode: error.response?.statusCode,
            data: error.response?.data,
          );
        }
        
        final errorMessage = error.message ?? '';
        return ServerException(
          message: errorMessage.isNotEmpty 
              ? 'Error: $errorMessage' 
              : 'An unexpected error occurred. Please try again.',
          statusCode: error.response?.statusCode,
        );
    }
  }

  /// Handle bad response errors
  AppException _handleBadResponse(Response? response) {
    final statusCode = response?.statusCode;
    final data = response?.data;

    String message = 'An error occurred';

    // Try to extract error message from response with multiple fallbacks
    if (data != null) {
      if (data is Map<String, dynamic>) {
        message = data['message'] ?? 
                  data['error'] ?? 
                  data['errorMessage'] ??
                  data['title'] ??
                  data['detail'] ??
                  message;
        
        // Check for nested error objects
        if (message == 'An error occurred' && data.containsKey('errors')) {
          final errors = data['errors'];
          if (errors is Map && errors.isNotEmpty) {
            message = errors.values.first.toString();
          } else if (errors is List && errors.isNotEmpty) {
            message = errors.first.toString();
          }
        }
      } else if (data is String) {
        message = data;
      }
    }

    switch (statusCode) {
      case 400:
        return ServerException(
          message: message,
          statusCode: statusCode,
          data: data,
        );
      case 401:
        // Trigger unauthorized callback if set
        if (_onUnauthorized != null) {
          _onUnauthorized!();
        }
        return UnauthorizedException(
          message: message.isNotEmpty && message != 'An error occurred' 
              ? message 
              : 'Session expired. Please log in again.',
        );
      case 403:
        return AuthException(
          message: message.isNotEmpty && message != 'An error occurred'
              ? message
              : 'Access denied. You don\'t have permission.',
          statusCode: statusCode,
        );
      case 404:
        return ServerException(
          message: message.isNotEmpty && message != 'An error occurred'
              ? message
              : 'Resource not found.',
          statusCode: statusCode,
        );
      case 500:
      case 502:
      case 503:
        return ServerException(
          message: message.isNotEmpty && message != 'An error occurred'
              ? message
              : 'Server error. Please try again later.',
          statusCode: statusCode,
        );
      default:
        return ServerException(
          message: message,
          statusCode: statusCode,
          data: data,
        );
    }
  }
}

