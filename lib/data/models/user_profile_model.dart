import 'package:equatable/equatable.dart';

/// User profile model from userinfo API
class UserProfileModel extends Equatable {
  final String? id;
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
  final Map<String, dynamic>? additionalData;

  const UserProfileModel({
    this.id,
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
    this.additionalData,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'],
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
      additionalData: json,
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
      if (additionalData != null) ...additionalData!,
    };
  }

  /// Get full name
  String get fullName {
    final parts = <String>[];
    if (firstName != null && firstName!.isNotEmpty) parts.add(firstName!);
    if (middleName != null && middleName!.isNotEmpty) parts.add(middleName!);
    if (lastName != null && lastName!.isNotEmpty) parts.add(lastName!);
    return parts.join(' ');
  }

  /// Backward compatibility getters
  String? get userId => id;
  String? get name => fullName.isNotEmpty ? fullName : null;
  String? get email => emailId;
  String? get phone => mobileNo;
  String get fullAddress => ''; // Not available in new API

  /// Get initials for avatar
  String get initials {
    if (firstName != null && firstName!.isNotEmpty) {
      if (lastName != null && lastName!.isNotEmpty) {
        return '${firstName![0]}${lastName![0]}'.toUpperCase();
      }
      return firstName!.substring(0, firstName!.length >= 2 ? 2 : 1).toUpperCase();
    }
    if (emailId != null && emailId!.isNotEmpty) {
      return emailId![0].toUpperCase();
    }
    return 'U';
  }

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
