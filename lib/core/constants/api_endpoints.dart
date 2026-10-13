/// API endpoint paths
class ApiEndpoints {
  ApiEndpoints._();

  // Authentication
  static const String login = '/api/v1/authorize';
  static const String refreshToken = '/api/Auth/refreshtoken';
  static const String userInfo = '/api/v1/profile';
  // Change password is POST /api/v1/profile { userId, password } on this API.
  static const String changePassword = '/api/v1/profile';

  // Employee
  static const String employee = '/api/v1/employee';

  // Helpdesk
  static const String ticketGetAll = '/api/v1/ticket/getAll';
  static const String ticket = '/api/v1/ticket';

  // Attendance
  static const String attendance = '/api/v1/attendence/getAllOrgAttendance';
  static const String postWebCheckIn = '/api/v1/attendence/postlatestwebcheckin';
  static const String getWebCheckIn = '/api/v1/attendence/getlatestwebcheckin';

  // Dashboard (server-driven)
  static const String dashboardLayout = '/api/v1/dashboard/layout';
  static const String dashboardCatalog = '/api/v1/dashboard/catalog';
  static const String counts = '/api/v1/counts';
  static const String countsCharts = '/api/v1/counts/charts';
  static const String countsPeople = '/api/v1/counts/people';
  static const String approvalsInbox = '/api/v1/counts/approvals-inbox';
  static const String todoDashboard = '/api/v1/todo/dashboard';
  static String todoComplete(int id) => '/api/v1/todo/$id/complete';
  static const String holidays = '/api/v1/profile/holidays';

  // Leave
  static const String leave = '/api/v1/leave';
  static const String leaveMine = '/api/v1/leave/me';
  static const String leaveInfo = '/api/v1/leave/myleaveinfo';
  static const String leaveDayCount = '/api/v1/leave/daycount';
  static const String leaveApprovals = '/api/v1/leave/approvals';
  static const String leaveBulkAction = '/api/v1/leave/approvals/bulk-action';
  // Withdraw = change status to Cancelled (InActivate is a hard delete used by admins).
  static String leaveCancel(int id) => '/api/v1/leave/$id/changestatus';
  static const String leaveTypesOptions = '/api/v1/admin/GetParentOptions/leavetypes';
  static const String dayTypesOptions = '/api/v1/admin/GetParentOptions/daystype';

  // Requests & payslips
  static const String regularize = '/api/v1/attendance-regularize';
  static const String regularizeList = '/api/v1/attendance-regularize/list';
  static String regularizeStatus(int id) => '/api/v1/attendance-regularize/$id/status';
  static const String regularizeTypesOptions = '/api/v1/admin/GetParentOptions/regularizetypes';
  static const String wfh = '/api/v1/wfh-requests';
  static const String wfhList = '/api/v1/wfh-requests/list';
  static String wfhStatus(int id) => '/api/v1/wfh-requests/$id/status';
  static const String payslipList = '/api/v1/payslip/getall';
  static const String payslipDownload = '/api/v1/payslip/download';

  // Notifications
  static const String notificationsUnread = '/api/v1/notifications/unread-count';
  static const String notificationsList = '/api/v1/notifications/list';
  static String notificationRead(int id) => '/api/v1/notifications/$id/read';
  static const String notificationsReadAll = '/api/v1/notifications/read-all';

  // Legacy/Deprecated - Keep for backward compatibility if needed
  static const String logout = '/logout';
  static const String profiles = '/profiles';
  static String profileDetails(String profileId) => '/profiles/$profileId';
  static const String submitVerification = '/submit-verification';
  static const String addMessage = '/add-message';
}
