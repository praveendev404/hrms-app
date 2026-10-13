import 'package:equatable/equatable.dart';

/// Base list info model
class BaseListInfo {
  final String? createdBy;
  final String? createdByName;
  final String? createdDate;
  final String? modifiedBy;
  final String? modifiedByName;
  final String? modifiedDate;
  final String? orgName;
  final String? profilePic;
  final int? employeeId;

  const BaseListInfo({
    this.createdBy,
    this.createdByName,
    this.createdDate,
    this.modifiedBy,
    this.modifiedByName,
    this.modifiedDate,
    this.orgName,
    this.profilePic,
    this.employeeId,
  });

  factory BaseListInfo.fromJson(Map<String, dynamic> json) {
    return BaseListInfo(
      createdBy: json['createdBy'] as String?,
      createdByName: json['createdByName'] as String?,
      createdDate: json['createdDate'] as String?,
      modifiedBy: json['modifiedBy'] as String?,
      modifiedByName: json['modifiedByName'] as String?,
      modifiedDate: json['modifiedDate'] as String?,
      orgName: json['orgName'] as String?,
      profilePic: json['profilePic'] as String?,
      employeeId: json['employeeId'] as int?,
    );
  }
}

/// Ticket model
class TicketModel extends Equatable {
  final int id;
  final int? empId;
  final int? ticketCategoryId;
  final String? subject;
  final String? body;
  final int? ticketStatusId;
  final int? assignedEmpId;
  final int? labelId;
  final int? proprityId;
  final String? empName;
  final String? ticketStatusName;
  final String? assignedEmpName;
  final String? labelName;
  final String? proprityName;
  final String? ticketCategoryName;
  final String? uniqueNo;
  final String? ticketStatusColor;
  final String? priorityColor;
  final String? labelColor;
  final dynamic custPropData;
  final BaseListInfo? baseListInfo;

  const TicketModel({
    required this.id,
    this.empId,
    this.ticketCategoryId,
    this.subject,
    this.body,
    this.ticketStatusId,
    this.assignedEmpId,
    this.labelId,
    this.proprityId,
    this.empName,
    this.ticketStatusName,
    this.assignedEmpName,
    this.labelName,
    this.proprityName,
    this.ticketCategoryName,
    this.uniqueNo,
    this.ticketStatusColor,
    this.priorityColor,
    this.labelColor,
    this.custPropData,
    this.baseListInfo,
  });

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    return TicketModel(
      id: json['id'] as int,
      empId: json['empId'] as int?,
      ticketCategoryId: json['ticketCategoryId'] as int?,
      subject: json['subject'] as String?,
      body: json['body'] as String?,
      ticketStatusId: json['ticketStatusId'] as int?,
      assignedEmpId: json['assignedEmpId'] as int?,
      labelId: json['labelId'] as int?,
      proprityId: json['proprityId'] as int?,
      empName: json['empName'] as String?,
      ticketStatusName: json['ticketStatusName'] as String?,
      assignedEmpName: json['assignedEmpName'] as String?,
      labelName: json['labelName'] as String?,
      proprityName: json['proprityName'] as String?,
      ticketCategoryName: json['ticketCategoryName'] as String?,
      uniqueNo: json['uniqueNo'] as String?,
      ticketStatusColor: json['ticketStatusColor'] as String?,
      priorityColor: json['priorityColor'] as String?,
      labelColor: json['labelColor'] as String?,
      custPropData: json['custPropData'],
      baseListInfo: json['baseListInfo'] != null
          ? BaseListInfo.fromJson(json['baseListInfo'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'empId': empId,
      'ticketCategoryId': ticketCategoryId,
      'subject': subject,
      'body': body,
      'ticketStatusId': ticketStatusId,
      'assignedEmpId': assignedEmpId,
      'labelId': labelId,
      'proprityId': proprityId,
      'empName': empName,
      'ticketStatusName': ticketStatusName,
      'assignedEmpName': assignedEmpName,
      'labelName': labelName,
      'proprityName': proprityName,
      'ticketCategoryName': ticketCategoryName,
      'uniqueNo': uniqueNo,
      'ticketStatusColor': ticketStatusColor,
      'priorityColor': priorityColor,
      'labelColor': labelColor,
      'custPropData': custPropData,
    };
  }

  String get displaySubject => subject ?? 'No Subject';
  String get displayBody => body ?? '';
  String get displayStatus => ticketStatusName ?? 'Unknown';
  String get displayPriority => proprityName ?? 'Unknown';
  String get displayCategory => ticketCategoryName ?? 'Uncategorized';
  String get displayTicketNumber => uniqueNo ?? '#${id.toString()}';

  @override
  List<Object?> get props => [
        id,
        subject,
        ticketStatusName,
        uniqueNo,
      ];
}

/// Ticket list response
class TicketListResponse extends Equatable {
  final List<TicketModel> list;
  final int totalRecords;

  const TicketListResponse({
    required this.list,
    required this.totalRecords,
  });

  factory TicketListResponse.fromJson(Map<String, dynamic> json) {
    return TicketListResponse(
      list: (json['list'] as List<dynamic>?)
              ?.map((e) => TicketModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalRecords: json['totalRecords'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [list, totalRecords];
}

/// Ticket request model
class TicketRequest {
  final int startIndex;
  final int pageSize;
  final String keyword;

  const TicketRequest({
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

/// Save ticket response
class SaveTicketResponse extends Equatable {
  final String message;
  final bool success;
  final String uniqueId;

  const SaveTicketResponse({
    required this.message,
    required this.success,
    required this.uniqueId,
  });

  factory SaveTicketResponse.fromJson(Map<String, dynamic> json) {
    return SaveTicketResponse(
      message: json['message'] as String? ?? '',
      success: json['success'] as bool? ?? false,
      uniqueId: json['uniqueId'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [message, success, uniqueId];
}

/// Save ticket request (for add/update)
class SaveTicketRequest {
  final TicketModel model;

  const SaveTicketRequest({required this.model});

  Map<String, dynamic> toJson() {
    return {
      'model': model.toJson(),
    };
  }
}
