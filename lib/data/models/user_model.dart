import 'package:equatable/equatable.dart';

/// User model for authentication
class UserModel extends Equatable {
  final String id;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? emailId;
  final String? mobileNo;
  final int? statusTypeId;
  final String? roleName;
  final String? roleId;
  final String? designation;
  final int? employeeId;

  const UserModel({
    required this.id,
    this.firstName,
    this.middleName,
    this.lastName,
    this.emailId,
    this.mobileNo,
    this.statusTypeId,
    this.roleName,
    this.roleId,
    this.designation,
    this.employeeId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      firstName: json['firstName'],
      middleName: json['middleName'],
      lastName: json['lastName'],
      emailId: json['emailId'],
      mobileNo: json['mobileNo'],
      statusTypeId: json['statusTypeId'],
      roleName: json['roleName'],
      roleId: json['roleId'],
      designation: json['designation'],
      employeeId: json['employeeId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'middleName': middleName,
      'lastName': lastName,
      'emailId': emailId,
      'mobileNo': mobileNo,
      'statusTypeId': statusTypeId,
      'roleName': roleName,
      'roleId': roleId,
      'designation': designation,
      'employeeId': employeeId,
    };
  }

  // Helper getters for backward compatibility
  String get userId => id;
  String? get email => emailId;
  String? get username => emailId;
  String get fullName => '${firstName ?? ''} ${middleName ?? ''} ${lastName ?? ''}'.trim();

  @override
  List<Object?> get props => [
        id,
        firstName,
        middleName,
        lastName,
        emailId,
        mobileNo,
        statusTypeId,
        roleName,
        roleId,
        designation,
        employeeId,
      ];
}

/// Login request model
class LoginRequest {
  final String? userName;
  final String? password;

  const LoginRequest({
    this.userName,
    this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'userName': userName,
      'password': password,
    };
  }
}

/// Login response model
class LoginResponse {
  final String? token;
  final String? refreshToken;
  final bool isAuthenticated;
  final bool isFirstTimeLogin;

  const LoginResponse({
    this.token,
    this.refreshToken,
    required this.isAuthenticated,
    required this.isFirstTimeLogin,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'],
      refreshToken: json['refreshToken'],
      isAuthenticated: json['isAuthenticated'] ?? false,
      isFirstTimeLogin: json['isFirstTimeLogin'] ?? false,
    );
  }

  // Legacy support - for backward compatibility
  String get accessToken => token ?? '';
  bool get isChangePassword => isFirstTimeLogin;
}

/// Refresh token request model
class RefreshRequestModel {
  final String? accessToken;
  final String? refreshToken;

  const RefreshRequestModel({
    this.accessToken,
    this.refreshToken,
  });

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
    };
  }
}

/// Token and refresh token response model
class TokenAndRefreshToken {
  final String accessToken;
  final String refreshToken;

  const TokenAndRefreshToken({
    required this.accessToken,
    required this.refreshToken,
  });

  factory TokenAndRefreshToken.fromJson(Map<String, dynamic> json) {
    return TokenAndRefreshToken(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
    );
  }
}

/// Change password request model
class ChangePasswordRequest {
  final String? password;

  const ChangePasswordRequest({
    this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'password': password,
    };
  }
}

