// Shared fake backend for the screenshot and end-to-end harnesses: canned JSON shaped like the
// real API, plus a log of every request the app makes.
import 'package:dio/dio.dart';
import 'package:vectoredge_hrms/core/network/api_client.dart';

String dateOffset(int plusDays) {
  final d = DateTime.now().add(Duration(days: plusDays));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

dynamic cannedResponse(String method, String path) {
  bool has(String s) => path.contains(s);

  // ---- write calls & auth (used by the end-to-end flows) ----
  if (path.endsWith('/api/v1/authorize')) {
    return {'token': 'test-token', 'refreshToken': 'r', 'isAuthenticated': true, 'isFirstTimeLogin': false};
  }
  if (has('/postlatestwebcheckin')) return {'success': true, 'message': 'Check-in recorded.'};
  if (has('/leave/daycount')) return {'noOfDays': 1, 'problem': 'None', 'isSubmittable': true, 'workingDaysBeforePartialDays': 1};
  if (method == 'POST' && path.endsWith('/api/v1/leave')) return {'success': true, 'message': 'Leave request saved'};
  if (has('/approvals/bulk-action')) return {'success': true, 'message': 'Updated'};
  if (has('/todo/upsert')) return {'success': true, 'message': 'Saved'};
  if (method == 'POST' && path.endsWith('/WorkLog')) return {'success': true, 'message': 'Saved'};
  if (has('/read')) return {'success': true, 'message': 'ok'};

  if (has('/api/v1/profile/holidays')) {
    return [
      {'name': 'Diwali', 'date': dateOffset(14)},
      {'name': 'Christmas', 'date': dateOffset(60)},
      {'name': 'New Year', 'date': dateOffset(80)},
    ];
  }
  if (path.endsWith('/api/v1/profile')) {
    return {
      'id': 'u-1',
      'firstName': 'Devsupport',
      'lastName': 'User',
      'designation': 'HR Manager',
      'employeeId': 7,
      'menuItems': [
        {
          'menuText': 'Dashboard', 'orderId': 1,
          'lstSubMenuItems': [{'navUrl': 'dashboard', 'menuText': 'Dashboard', 'orderId': 1}],
        },
        {
          'menuText': 'Leave Management', 'orderId': 5,
          'lstSubMenuItems': [
            {'navUrl': 'leaves', 'menuText': 'My Leaves', 'orderId': 1},
            {'navUrl': 'leaves/approvals', 'menuText': 'My Team Approvals', 'orderId': 2},
            {'navUrl': 'leaves/hrApprovals', 'menuText': 'HR Approvals', 'orderId': 3},
          ],
        },
        {
          'menuText': 'Time and Attendance', 'orderId': 8,
          'lstSubMenuItems': [
            {'navUrl': 'timemgmt', 'menuText': 'My Attendance', 'orderId': 1},
            {'navUrl': 'timesheet/my', 'menuText': 'My Timesheet', 'orderId': 2},
          ],
        },
        {
          'menuText': 'Payroll', 'orderId': 6,
          'lstSubMenuItems': [
            {'navUrl': 'payroll/payslips', 'menuText': 'Payslips', 'orderId': 1},
            {'navUrl': 'myfinance/summary', 'menuText': 'My Finance', 'orderId': 2},
          ],
        },
        {
          'menuText': 'Analytics', 'orderId': 21,
          'lstSubMenuItems': [{'navUrl': 'analytics', 'menuText': 'HR Analytics', 'orderId': 1}],
        },
      ],
    };
  }
  if (has('/dashboard/layout')) {
    Map<String, dynamic> i(String id, int w, int h) => {'id': id, 'w': w, 'h': h};
    return {
      'source': 'default', 'adjusted': false, 'schemaVersion': 1,
      'items': [
        i('att.web-checkin', 12, 2), i('quick-actions', 12, 1),
        i('counts.leaves.mine', 3, 1), i('counts.tickets.mine', 3, 1),
        i('counts.pending-approvals', 3, 1), i('counts.compoff-balance', 3, 1),
        i('chart.my-leave-balance', 4, 3), i('list.approvals-inbox', 6, 3),
        i('list.my-recent-leaves', 6, 3), i('list.holidays', 4, 3),
        i('people.celebrations', 3, 4), i('chart.headcount-trend', 6, 3),
      ],
    };
  }
  if (has('/dashboard/catalog')) {
    Map<String, dynamic> c(String id, String t) => {'id': id, 'title': t, 'category': 'Me', 'refreshSeconds': null};
    return {
      'items': [
        c('counts.leaves.mine', 'My Leave Requests'), c('counts.tickets.mine', 'My Tickets'),
        c('counts.pending-approvals', 'Pending Approvals'), c('counts.compoff-balance', 'Comp-Off Balance'),
        c('chart.my-leave-balance', 'My Leave Balances'), c('list.approvals-inbox', 'Approvals Inbox'),
        c('list.my-recent-leaves', 'My Recent Leave Requests'), c('list.holidays', 'Upcoming Holidays'),
        c('people.celebrations', 'Birthdays & Anniversaries'), c('chart.headcount-trend', 'Headcount Trend (6 months)'),
      ],
    };
  }
  if (has('/counts/approvals-inbox')) {
    return {
      'items': [
        {'type': 'leave', 'label': 'Leave requests', 'count': 3, 'scope': 'team'},
        {'type': 'timesheet', 'label': 'Timesheets', 'count': 2, 'scope': 'team'},
        {'type': 'regularization', 'label': 'Regularization', 'count': 1, 'scope': 'all'},
      ],
      'total': 6,
    };
  }
  if (has('/counts/charts')) {
    return {
      'chartType': 'x',
      'dataPoints': [
        {'label': 'May', 'value': 118}, {'label': 'Jun', 'value': 124}, {'label': 'Jul', 'value': 131},
        {'label': 'Aug', 'value': 129}, {'label': 'Sep', 'value': 140}, {'label': 'Oct', 'value': 146},
      ],
    };
  }
  if (has('/counts/people')) {
    return {
      'birthdays': [{'name': 'Anita Rao', 'dateLabel': '14 Oct', 'dept': 'Finance'}],
      'anniversaries': [{'name': 'Ravi Kumar', 'dateLabel': '15 Oct 2021', 'yearsOfService': 5}],
      'newJoinees': [{'name': 'Meera Shah', 'dept': 'Engineering'}],
    };
  }
  if (has('/counts/analytics-summary')) {
    return {
      'totalEmployees': 146, 'newJoineesThisMonth': 6, 'exitsThisMonth': 2, 'attritionRatePercent': 4.2,
      'openJobPositions': 9, 'totalCandidatesThisMonth': 41, 'leaveDaysThisMonth': 88, 'pendingLeaveRequests': 7,
    };
  }
  if (path.endsWith('/api/v1/counts')) return {'key': 'x', 'value': 4};
  if (has('/todo/dashboard')) {
    return {
      'overdue': [{'id': 1, 'title': 'Submit travel claim', 'dueDate': dateOffset(-2), 'isOverdue': true}],
      'dueToday': [{'id': 2, 'title': 'Review onboarding checklist', 'dueDate': dateOffset(0)}],
      'upcoming': [],
    };
  }
  if (has('/todo/list')) {
    return {
      'today': dateOffset(0),
      'items': [
        {'id': 1, 'title': 'Submit travel claim', 'dueDate': dateOffset(-2), 'isOverdue': true, 'priority': 3},
        {'id': 2, 'title': 'Review onboarding checklist', 'dueDate': dateOffset(0), 'priority': 2, 'description': 'Check IT and HR tasks'},
        {'id': 3, 'title': 'Team 1:1 prep', 'dueDate': dateOffset(2), 'dueTime': '15:30:00'},
        {'id': 4, 'title': 'Book flights', 'dueDate': dateOffset(-1), 'isCompleted': true},
      ],
    };
  }
  if (has('/leave/myleaveinfo')) {
    return [
      {'leaveTypeId': 1, 'leaveTypeName': 'Casual Leave', 'totalLeaves': 12, 'usedLeaves': 4},
      {'leaveTypeId': 2, 'leaveTypeName': 'Sick Leave', 'totalLeaves': 8, 'usedLeaves': 1},
      {'leaveTypeId': 3, 'leaveTypeName': 'Earned Leave', 'totalLeaves': 15, 'usedLeaves': 6.5},
    ];
  }
  if (has('/leave/me')) {
    return {
      'totalRecords': 3,
      'list': [
        {
          'id': 1, 'leaveTypeName': 'Casual Leave', 'fromDate': dateOffset(5), 'toDate': dateOffset(6), 'noOfDays': 2,
          'leaveStatusTypeId': 1, 'leaveStatusTypeName': 'Created', 'reason': 'Family function',
          'approvalList': [{'empName': 'Anita Rao', 'leaveStatusName': 'Created'}],
        },
        {
          'id': 2, 'leaveTypeName': 'Sick Leave', 'fromDate': dateOffset(-12), 'toDate': dateOffset(-12), 'noOfDays': 1,
          'leaveStatusTypeId': 2, 'leaveStatusTypeName': 'Approved', 'reason': 'Fever',
        },
        {
          'id': 3, 'leaveTypeName': 'Earned Leave', 'fromDate': dateOffset(-40), 'toDate': dateOffset(-36), 'noOfDays': 5,
          'leaveStatusTypeId': 4, 'leaveStatusTypeName': 'Rejected', 'reason': 'Vacation',
        },
      ],
    };
  }
  if (has('/leave/approvals') || has('/leave/GetAll')) {
    return {
      'list': [
        {'id': 11, 'employeeName': 'Ravi Kumar', 'fromDate': dateOffset(2), 'toDate': dateOffset(3), 'noOfDays': 2, 'reason': 'Wedding', 'leaveStatusTypeId': 1},
        {'id': 12, 'employeeName': 'Meera Shah', 'fromDate': dateOffset(7), 'toDate': dateOffset(7), 'noOfDays': 0.5, 'reason': 'Doctor visit', 'leaveStatusTypeId': 1},
      ],
    };
  }
  if (has('/GetParentOptions/leavetypes')) {
    return [{'value': 1, 'label': 'Casual Leave', 'isNonEditable': false}, {'value': 2, 'label': 'Sick Leave', 'isNonEditable': false}];
  }
  if (has('/GetParentOptions/daystype')) {
    return [{'value': 1, 'label': 'Full Day', 'isNonEditable': false}, {'value': 2, 'label': 'Half Day', 'isNonEditable': false}];
  }
  if (has('/GetParentOptions/projects')) return [{'value': 1, 'label': 'Atlas Platform', 'isNonEditable': false}];
  if (has('/GetParentOptions/worklogtypes')) return [{'value': 1, 'label': 'Regular', 'isNonEditable': false}];
  if (has('/notifications/unread-count')) return {'count': 3};
  if (has('/notifications/list')) {
    return {
      'list': [
        {'id': 1, 'type': 'LeaveDecided', 'title': 'Leave Approved', 'message': 'Sick Leave on ${dateOffset(-12)} was approved.', 'isRead': false, 'createdDate': DateTime.now().toIso8601String()},
        {'id': 2, 'type': 'Regularize', 'title': 'Regularization request from Ravi', 'message': 'Missed punch-out', 'isRead': false, 'createdDate': DateTime.now().toIso8601String()},
        {'id': 3, 'type': 'Ticket', 'title': 'Ticket #TKT-102 updated', 'message': 'Status changed to In Progress', 'isRead': true, 'createdDate': DateTime.now().toIso8601String()},
      ],
    };
  }
  if (has('/getlatestwebcheckin')) return null;
  if (has('/getdetailAttendence')) {
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < 20; i++) {
      final wk = DateTime.now().subtract(Duration(days: i)).weekday;
      final weekend = wk == 6 || wk == 7;
      out.add({
        'date': dateOffset(-i),
        if (!weekend) 'firstPunchIn': '09:${10 + (i % 4) * 5}',
        if (!weekend) 'lastPunchOut': i == 3 ? null : '18:2${i % 6}',
        'totalHours': weekend ? 0 : (i == 3 ? 4.5 : 8.0 + (i % 3) * 0.5),
        'isLate': !weekend && i % 5 == 1,
        'lateByMinutes': i % 5 == 1 ? 18 : 0,
        'isMissingPunchOut': i == 3,
        'isWfh': i == 6,
        'logs': weekend ? [] : [{'id': 1}, {'id': 2}],
      });
    }
    return out;
  }
  if (has('/payslip/getall')) {
    return {
      'list': [
        {'id': 1, 'paySlip': 'a.pdf', 'fromDate': '2026-09-01', 'toDate': '2026-09-30'},
        {'id': 2, 'paySlip': 'b.pdf', 'fromDate': '2026-08-01', 'toDate': '2026-08-31'},
        {'id': 3, 'paySlip': 'c.pdf', 'fromDate': '2026-07-01', 'toDate': '2026-07-31'},
      ],
    };
  }
  if (has('/timesheet/week')) {
    return {'id': 5, 'timesheetStatusTypeId': 1, 'timesheetStatusTypeName': 'Draft', 'fromDate': dateOffset(-DateTime.now().weekday + 1), 'toDate': dateOffset(-DateTime.now().weekday + 7)};
  }
  if (has('/WorkLog/getall')) {
    return {
      'list': [
        {'id': 1, 'projectName': 'Atlas Platform', 'workLogTypeName': 'Regular', 'date': dateOffset(0), 'duration': 6, 'comments': 'API integration', 'isBillable': true},
        {'id': 2, 'projectName': 'Atlas Platform', 'workLogTypeName': 'Regular', 'date': dateOffset(0), 'duration': 2, 'comments': 'Code review', 'isBillable': false},
      ],
    };
  }
  if (has('/timesheet/getall')) return {'list': []};
  if (has('/feed/getall')) {
    return {
      'list': [
        {
          'id': 1, 'header': 'Office closed on Diwali', 'body': '<p>The office will remain closed on <b>8 Nov</b>.</p>',
          'feedTypeName': 'Announcement', 'commentsCount': 2, 'reactionsCount': 14, 'empReactionTypeId': 1,
          'baseListInfo': {'createdByName': 'HR Team', 'createdDate': DateTime.now().toIso8601String()},
        },
        {
          'id': 2, 'header': 'Welcome Meera!', 'body': 'Please join us in welcoming Meera to Engineering.',
          'feedTypeName': 'Post', 'commentsCount': 0, 'reactionsCount': 5, 'empReactionTypeId': 0,
          'baseListInfo': {'createdByName': 'Anita Rao', 'createdDate': DateTime.now().toIso8601String()},
        },
      ],
    };
  }
  if (has('/recognition/record/getall')) {
    return {
      'list': [
        {'id': 1, 'senderName': 'Anita Rao', 'recipientName': 'Ravi Kumar', 'badgeName': 'Team Player', 'badgeEmoji': '🤝', 'message': 'Great teamwork on the release!', 'recognizedOn': DateTime.now().toIso8601String()},
      ],
    };
  }
  if (has('/recognition/record/leaderboard')) {
    return [
      {'rank': 1, 'employeeName': 'Ravi Kumar', 'designation': 'Engineer', 'recognitionCount': 9},
      {'rank': 2, 'employeeName': 'Meera Shah', 'designation': 'Designer', 'recognitionCount': 6},
    ];
  }
  if (has('/performance/goal/getall')) {
    return {
      'list': [
        {'id': 1, 'cycleId': 3, 'cycleName': 'FY 2026 Annual', 'title': 'Ship mobile app v1', 'goalTypeId': 1, 'weightPercentage': 40, 'goalStatusTypeId': 3, 'goalStatusTypeName': 'Approved', 'targetValue': '100%'},
        {'id': 2, 'cycleId': 3, 'cycleName': 'FY 2026 Annual', 'title': 'Mentor two juniors', 'goalTypeId': 2, 'weightPercentage': 20, 'goalStatusTypeId': 1, 'goalStatusTypeName': 'Draft'},
      ],
    };
  }
  if (has('/performance/review/my')) {
    return {
      'list': [
        {'id': 1, 'cycleId': 3, 'cycleName': 'FY 2026 Annual', 'reviewStatusTypeId': 3, 'selfScore': 4, 'selfComments': 'Delivered the roadmap.', 'managerScore': 4, 'managerComments': 'Strong year.'},
      ],
    };
  }
  if (has('/performance/feedback')) return {'list': []};
  if (has('/emploan/my-loans')) {
    return {
      'list': [
        {'id': 1, 'amount': 100000, 'loanTakenOn': '2026-01-10', 'percentage': 6, 'payTypeName': 'Salary advance', 'totalPaid': 40000, 'balanceAmount': 60000, 'emiAmount': 10000, 'emiEffectiveDate': '2026-03-01', 'isActive': true},
      ],
    };
  }
  if (has('/empsaldetail/GetMySalaryDetails')) {
    return {'list': [{'id': 9, 'ctc': 1800000, 'bonusAmount': 100000, 'effectiveFrom': '2026-04-01', 'isActive': true}]};
  }
  if (has('/tax/form16/list')) return {'list': []};
  if (has('/wfh-requests/list') || has('/attendance-regularize/list') || has('/late-comers/list')) return {'list': []};
  if (has('/compoff/GetAll')) return {'list': []};
  return {'list': [], 'totalRecords': 0};
}

class FakeApiClient extends ApiClient {
  /// Every request the app made, in order (method, path, body) - for assertions.
  final List<({String method, String path, dynamic body})> calls = [];

  void _log(String m, String p, dynamic b) => calls.add((method: m, path: p, body: b));

  Response<T> _resp<T>(String path, dynamic data) =>
      Response<T>(requestOptions: RequestOptions(path: path), statusCode: 200, data: data as T?);

  @override
  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters, Options? options}) async =>
      (() { _log('GET', path, queryParameters); return _resp<T>(path, cannedResponse('GET', path)); })();

  @override
  Future<Response<T>> post<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async =>
      (() { _log('POST', path, data); return _resp<T>(path, cannedResponse('POST', path)); })();

  @override
  Future<Response<T>> put<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async =>
      (() { _log('PUT', path, data); return _resp<T>(path, cannedResponse('PUT', path)); })();

  @override
  Future<Response<T>> delete<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async =>
      (() { _log('DELETE', path, data); return _resp<T>(path, cannedResponse('DELETE', path)); })();
}

