import 'package:equatable/equatable.dart';

/// Employee model
class EmployeeModel extends Equatable {
  final int? id;
  final String? firstName;
  final String? lastName;
  final String? middleName;
  final String? gender;
  final int? maritalStatusId;
  final String? maritalStatusName;
  final String? dob;
  final String? nationality;
  final String? bloodGroup;
  final String? profilePic;
  final String? empCode;
  final String? designation;
  final String? department;
  final String? joiningDate;
  final String? relevingDate;
  final String? emailId;
  final String? empStatusTypeId;
  final String? mobileNo;
  final String? designationId;
  final String? departmentId;
  final String? empStatusType;
  final int? businessUnitId;
  final String? businessUnitName;
  final String? reportingToName;
  final int? reportingTo;
  final bool? doCreateLogin;
  final String? userId;
  final String? createdBy;
  final String? userRoleId;
  final String? role;
  final String? personalEmailId;
  final String? orgName;
  final dynamic custPropData;

  const EmployeeModel({
    this.id,
    this.firstName,
    this.lastName,
    this.middleName,
    this.gender,
    this.maritalStatusId,
    this.maritalStatusName,
    this.dob,
    this.nationality,
    this.bloodGroup,
    this.profilePic,
    this.empCode,
    this.designation,
    this.department,
    this.joiningDate,
    this.relevingDate,
    this.emailId,
    this.empStatusTypeId,
    this.mobileNo,
    this.designationId,
    this.departmentId,
    this.empStatusType,
    this.businessUnitId,
    this.businessUnitName,
    this.reportingToName,
    this.reportingTo,
    this.doCreateLogin,
    this.userId,
    this.createdBy,
    this.userRoleId,
    this.role,
    this.personalEmailId,
    this.orgName,
    this.custPropData,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: json['id'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      middleName: json['middleName'],
      gender: json['gender'],
      maritalStatusId: json['maritalStatusId'],
      maritalStatusName: json['maritalStatusName'],
      dob: json['dob'],
      nationality: json['nationality'],
      bloodGroup: json['bloodGroup'],
      profilePic: json['profilePic'],
      empCode: json['empCode'],
      designation: json['designation'],
      department: json['department'],
      joiningDate: json['joiningDate'],
      relevingDate: json['relevingDate'],
      emailId: json['emailId'],
      empStatusTypeId: json['empStatusTypeId'],
      mobileNo: json['mobileNo'],
      designationId: json['designationId'],
      departmentId: json['departmentId'],
      empStatusType: json['empStatusType'],
      businessUnitId: json['businessUnitId'],
      businessUnitName: json['businessUnitName'],
      reportingToName: json['reportingToName'],
      reportingTo: json['reportingTo'],
      doCreateLogin: json['doCreateLogin'],
      userId: json['userId'],
      createdBy: json['createdBy'],
      userRoleId: json['userRoleId'],
      role: json['role'],
      personalEmailId: json['personalEmailId'],
      orgName: json['orgName'],
      custPropData: json['custPropData'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'middleName': middleName,
      'gender': gender,
      'maritalStatusId': maritalStatusId,
      'maritalStatusName': maritalStatusName,
      'dob': dob,
      'nationality': nationality,
      'bloodGroup': bloodGroup,
      'profilePic': profilePic,
      'empCode': empCode,
      'designation': designation,
      'department': department,
      'joiningDate': joiningDate,
      'relevingDate': relevingDate,
      'emailId': emailId,
      'empStatusTypeId': empStatusTypeId,
      'mobileNo': mobileNo,
      'designationId': designationId,
      'departmentId': departmentId,
      'empStatusType': empStatusType,
      'businessUnitId': businessUnitId,
      'businessUnitName': businessUnitName,
      'reportingToName': reportingToName,
      'reportingTo': reportingTo,
      'doCreateLogin': doCreateLogin,
      'userId': userId,
      'createdBy': createdBy,
      'userRoleId': userRoleId,
      'role': role,
      'personalEmailId': personalEmailId,
      'orgName': orgName,
      'custPropData': custPropData,
    };
  }

  String get fullName {
    final parts = <String>[];
    if (firstName != null && firstName!.isNotEmpty) parts.add(firstName!);
    if (middleName != null && middleName!.isNotEmpty) parts.add(middleName!);
    if (lastName != null && lastName!.isNotEmpty) parts.add(lastName!);
    return parts.join(' ').trim();
  }

  String get initials {
    if (firstName != null && firstName!.isNotEmpty) {
      if (lastName != null && lastName!.isNotEmpty) {
        return '${firstName![0]}${lastName![0]}'.toUpperCase();
      }
      return firstName!.substring(0, firstName!.length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'E';
  }

  @override
  List<Object?> get props => [
        id,
        firstName,
        lastName,
        empCode,
        emailId,
        designation,
        department,
      ];
}

/// Employee list response
class EmployeeListResponse extends Equatable {
  final List<EmployeeModel> list;
  final int totalRecords;

  const EmployeeListResponse({
    required this.list,
    required this.totalRecords,
  });

  factory EmployeeListResponse.fromJson(Map<String, dynamic> json) {
    return EmployeeListResponse(
      list: (json['list'] as List<dynamic>?)
              ?.map((e) => EmployeeModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalRecords: json['totalRecords'] ?? 0,
    );
  }

  @override
  List<Object?> get props => [list, totalRecords];
}

/// Employee request model
class EmployeeRequest {
  final int startIndex;
  final int pageSize;
  final String keyword;

  const EmployeeRequest({
    this.startIndex = 0,
    this.pageSize = 10,
    this.keyword = '',
  });

  Map<String, dynamic> toJson() {
    final pageModel = <String, dynamic>{
      'startIndex': startIndex,
      'pageSize': pageSize,
    };
    
    if (keyword.isNotEmpty) {
      pageModel['keyWord'] = keyword;
    }
    
    return {
      'pageModel': pageModel,
    };
  }
}
