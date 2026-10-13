import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/dashboard_remote_datasource.dart';
import '../../data/datasources/extras_remote_datasource.dart';
import '../../data/datasources/leave_remote_datasource.dart';
import '../../data/datasources/notification_remote_datasource.dart';
import '../../data/datasources/request_remote_datasource.dart';
import '../../data/datasources/ticket_remote_datasource.dart';
import '../../data/datasources/social_remote_datasource.dart';
import '../../data/models/dashboard_models.dart';
import '../../data/models/dropdown_option_model.dart';
import '../../data/models/extras_models.dart';
import '../../data/models/leave_models.dart';
import '../../data/models/request_models.dart';
import '../../data/models/social_models.dart';
import '../../data/models/ticket_model.dart';
import '../../data/models/work_models.dart';
import 'providers.dart';

// ============ Data sources ============

final dashboardDataSourceProvider = Provider<DashboardRemoteDataSource>(
  (ref) => DashboardRemoteDataSource(ref.watch(apiClientProvider)),
);

final leaveDataSourceProvider = Provider<LeaveRemoteDataSource>(
  (ref) => LeaveRemoteDataSource(ref.watch(apiClientProvider)),
);

final notificationDataSourceProvider = Provider<NotificationRemoteDataSource>(
  (ref) => NotificationRemoteDataSource(ref.watch(apiClientProvider)),
);

// ============ Dashboard (server-driven) ============

/// Ordered widgets the server decided this user may see (capability-filtered).
final dashboardLayoutProvider = FutureProvider.autoDispose<DashboardLayout>(
  (ref) => ref.watch(dashboardDataSourceProvider).getLayout(),
);

/// Titles / refresh intervals for those widgets.
final dashboardCatalogProvider = FutureProvider.autoDispose<Map<String, DashboardCatalogItem>>(
  (ref) => ref.watch(dashboardDataSourceProvider).getCatalog(),
);

final countWidgetProvider = FutureProvider.autoDispose.family<int, String>(
  (ref, type) => ref.watch(dashboardDataSourceProvider).getCount(type),
);

final chartWidgetProvider = FutureProvider.autoDispose.family<List<ChartPoint>, String>(
  (ref, chartType) => ref.watch(dashboardDataSourceProvider).getChart(chartType),
);

final peopleWidgetProvider = FutureProvider.autoDispose<PeopleWidgets>(
  (ref) => ref.watch(dashboardDataSourceProvider).getPeople(),
);

final approvalsInboxProvider = FutureProvider.autoDispose<ApprovalsInbox>(
  (ref) => ref.watch(dashboardDataSourceProvider).getApprovalsInbox(),
);

final todosWidgetProvider = FutureProvider.autoDispose<TodoDashboard>(
  (ref) => ref.watch(dashboardDataSourceProvider).getTodos(),
);

final holidaysProvider = FutureProvider.autoDispose<List<HolidayItem>>(
  (ref) => ref.watch(dashboardDataSourceProvider).getHolidays(),
);

// ============ Leave ============

final leaveBalancesProvider = FutureProvider.autoDispose<List<LeaveBalance>>(
  (ref) => ref.watch(leaveDataSourceProvider).getBalances(),
);

final myLeaveRequestsProvider = FutureProvider.autoDispose<List<LeaveRequest>>(
  (ref) => ref.watch(leaveDataSourceProvider).getMyRequests(),
);

final leaveTypeOptionsProvider = FutureProvider.autoDispose<List<DropdownOptionModel>>(
  (ref) => ref.watch(leaveDataSourceProvider).getLeaveTypes(),
);

final dayTypeOptionsProvider = FutureProvider.autoDispose<List<DropdownOptionModel>>(
  (ref) => ref.watch(leaveDataSourceProvider).getDayTypes(),
);

final leaveApprovalsProvider = FutureProvider.autoDispose<List<LeaveApproval>>(
  (ref) => ref.watch(leaveDataSourceProvider).getApprovals(),
);

// ============ Notifications ============

final unreadNotificationsProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(notificationDataSourceProvider).getUnreadCount(),
);

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>(
  (ref) => ref.watch(notificationDataSourceProvider).getList(),
);

// ============ Requests & payslips ============

final requestDataSourceProvider = Provider<RequestRemoteDataSource>(
  (ref) => RequestRemoteDataSource(ref.watch(apiClientProvider)),
);

final regularizationsProvider = FutureProvider.autoDispose<List<RegularizeItem>>(
  (ref) => ref.watch(requestDataSourceProvider).getRegularizations(),
);

final regularizeTypeOptionsProvider = FutureProvider.autoDispose<List<DropdownOptionModel>>(
  (ref) => ref.watch(requestDataSourceProvider).getRegularizeTypes(),
);

final myWfhProvider = FutureProvider.autoDispose<List<WfhItem>>(
  (ref) => ref.watch(requestDataSourceProvider).getWfh(scope: 'own'),
);

/// Pending WFH requests waiting on me (team scope for managers).
final wfhApprovalsProvider = FutureProvider.autoDispose<List<WfhItem>>(
  (ref) => ref.watch(requestDataSourceProvider).getWfh(scope: 'team', statusTypeId: WfhStatus.pending),
);

final payslipsProvider = FutureProvider.autoDispose.family<List<PayslipItem>, int>(
  (ref, year) => ref.watch(requestDataSourceProvider).getPayslips(year),
);

// ============ Feed, who's out, assets, learning ============

final extrasDataSourceProvider = Provider<ExtrasRemoteDataSource>(
  (ref) => ExtrasRemoteDataSource(ref.watch(apiClientProvider)),
);

final feedProvider = FutureProvider.autoDispose<List<FeedPost>>(
  (ref) => ref.watch(extrasDataSourceProvider).getFeed(),
);

final feedCommentsProvider = FutureProvider.autoDispose.family<List<FeedComment>, int>(
  (ref, feedId) => ref.watch(extrasDataSourceProvider).getComments(feedId),
);

final outTodayProvider = FutureProvider.autoDispose<List<LeaveRequest>>(
  (ref) => ref.watch(extrasDataSourceProvider).getOutToday(),
);

final myAssetsProvider = FutureProvider.autoDispose<List<AssetItem>>(
  (ref) => ref.watch(extrasDataSourceProvider).getMyAssets(),
);

final myEnrollmentsProvider = FutureProvider.autoDispose<List<CourseEnrollment>>(
  (ref) => ref.watch(extrasDataSourceProvider).getMyEnrollments(),
);

final courseCatalogProvider = FutureProvider.autoDispose<List<CatalogCourse>>(
  (ref) => ref.watch(extrasDataSourceProvider).getCatalog(),
);

// ============ Recognition & surveys ============

final socialDataSourceProvider = Provider<SocialRemoteDataSource>(
  (ref) => SocialRemoteDataSource(ref.watch(apiClientProvider)),
);

final recognitionWallProvider = FutureProvider.autoDispose<List<RecognitionRecord>>(
  (ref) => ref.watch(socialDataSourceProvider).getRecords(),
);

final myRecognitionsProvider = FutureProvider.autoDispose<List<RecognitionRecord>>(
  (ref) => ref.watch(socialDataSourceProvider).getRecords(mine: true),
);

final leaderboardProvider = FutureProvider.autoDispose<List<LeaderEntry>>(
  (ref) => ref.watch(socialDataSourceProvider).getLeaderboard(),
);

final recognitionBadgesProvider = FutureProvider.autoDispose<List<RecognitionBadge>>(
  (ref) => ref.watch(socialDataSourceProvider).getBadges(),
);

final mySurveysProvider = FutureProvider.autoDispose<List<Survey>>(
  (ref) => ref.watch(socialDataSourceProvider).getMySurveys(),
);

final recentTicketsProvider = FutureProvider.autoDispose<List<TicketModel>>((ref) async {
  final res = await TicketRemoteDataSourceImpl(apiClient: ref.watch(apiClientProvider))
      .getTickets(const TicketRequest(startIndex: 0, pageSize: 5));
  return res.list;
});

final performanceSummaryProvider = FutureProvider.autoDispose<PerformanceSummary?>(
  (ref) => ref.watch(extrasDataSourceProvider).getPerformanceSummary(),
);

/// Keyed by "yyyy-MM".
final myAttendanceProvider = FutureProvider.autoDispose.family<List<AttendanceDay>, String>((ref, ym) {
  final parts = ym.split('-');
  return ref.watch(extrasDataSourceProvider).getMyAttendance(DateTime(int.parse(parts[0]), int.parse(parts[1])));
});

final weekStartDayProvider = FutureProvider<int>(
  (ref) => ref.watch(extrasDataSourceProvider).getWeekStartDay(),
);

/// Keyed by "fromDate|toDate" (yyyy-MM-dd).
final timesheetWeekProvider = FutureProvider.autoDispose.family<TimesheetSheet, String>((ref, key) {
  final p = key.split('|');
  return ref.watch(extrasDataSourceProvider).getOrCreateWeek(fromDate: p[0], toDate: p[1]);
});

final workLogsProvider = FutureProvider.autoDispose.family<List<WorkLog>, int>(
  (ref, timesheetId) => ref.watch(extrasDataSourceProvider).getWorkLogs(timesheetId),
);

final projectOptionsProvider = FutureProvider.autoDispose<List<DropdownOptionModel>>(
  (ref) => ref.watch(extrasDataSourceProvider).getOptions('projects'),
);

final workLogTypeOptionsProvider = FutureProvider.autoDispose<List<DropdownOptionModel>>(
  (ref) => ref.watch(extrasDataSourceProvider).getOptions('worklogtypes'),
);

final myCompOffProvider = FutureProvider.autoDispose.family<List<CompOffItem>, int>(
  (ref, employeeId) => ref.watch(extrasDataSourceProvider).getMyCompOffs(employeeId),
);

final keyResultsProvider = FutureProvider.autoDispose.family<List<PerfKeyResult>, int>(
  (ref, goalId) => ref.watch(extrasDataSourceProvider).getKeyResults(goalId),
);

final feedback360Provider = FutureProvider.autoDispose.family<List<Perf360Feedback>, int>(
  (ref, reviewId) => ref.watch(extrasDataSourceProvider).get360(reviewId),
);

final competencyRatingsProvider = FutureProvider.autoDispose.family<List<CompetencyRating>, int>(
  (ref, reviewId) => ref.watch(extrasDataSourceProvider).getCompetencyRatings(reviewId),
);

final myGoalsProvider = FutureProvider.autoDispose<List<PerfGoal>>(
  (ref) => ref.watch(extrasDataSourceProvider).getMyGoals(),
);

final myReviewsProvider = FutureProvider.autoDispose<List<PerfReview>>(
  (ref) => ref.watch(extrasDataSourceProvider).getMyReviews(),
);

final knownCyclesProvider = FutureProvider.autoDispose<List<PerfCycleRef>>(
  (ref) => ref.watch(extrasDataSourceProvider).getKnownCycles(),
);

/// true = received, false = given.
final feedbackProvider = FutureProvider.autoDispose.family<List<PerfFeedback>, bool>(
  (ref, received) => ref.watch(extrasDataSourceProvider).getFeedback(received: received),
);

/// All my to-dos from 30 days ago to 60 days ahead (server caps a range at 93 days).
final todoListProvider = FutureProvider.autoDispose<List<TodoItem>>((ref) {
  String f(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final now = DateTime.now();
  return ref
      .watch(dashboardDataSourceProvider)
      .listTodos(f(now.subtract(const Duration(days: 30))), f(now.add(const Duration(days: 60))));
});

final myResignationProvider = FutureProvider.autoDispose.family<ResignationItem?, int>(
  (ref, employeeId) => ref.watch(extrasDataSourceProvider).getMyResignation(employeeId),
);

final myLoansProvider = FutureProvider.autoDispose<List<LoanItem>>(
  (ref) => ref.watch(extrasDataSourceProvider).getMyLoans(),
);

final mySalariesProvider = FutureProvider.autoDispose<List<SalaryRecord>>(
  (ref) => ref.watch(extrasDataSourceProvider).getMySalaries(),
);

final salaryBreakupProvider = FutureProvider.autoDispose.family<List<SalaryComponent>, int>(
  (ref, id) => ref.watch(extrasDataSourceProvider).getSalaryBreakup(id),
);

final mySkillsProvider = FutureProvider.autoDispose.family<List<MySkill>, int>(
  (ref, employeeId) => ref.watch(extrasDataSourceProvider).getMySkills(employeeId),
);

final skillCatalogProvider = FutureProvider.autoDispose<List<SkillRef>>(
  (ref) => ref.watch(extrasDataSourceProvider).getSkillCatalog(),
);

final myOnboardingTasksProvider = FutureProvider.autoDispose<List<OnbTask>>(
  (ref) => ref.watch(extrasDataSourceProvider).getMyOnboardingTasks(),
);

final form16Provider = FutureProvider.autoDispose.family<List<Form16Item>, int>(
  (ref, employeeId) => ref.watch(requestDataSourceProvider).getForm16List(employeeId),
);

final timesheetsToReviewProvider = FutureProvider.autoDispose<List<TimesheetReviewItem>>(
  (ref) => ref.watch(requestDataSourceProvider).getTimesheetsToReview(),
);

final timesheetLogsProvider = FutureProvider.autoDispose.family<List<WorkLog>, int>(
  (ref, id) => ref.watch(requestDataSourceProvider).getWorkLogsOf(id),
);

final compOffsToReviewProvider = FutureProvider.autoDispose<List<CompOffItem>>(
  (ref) => ref.watch(requestDataSourceProvider).getCompOffsToReview(),
);

final lateEntriesProvider = FutureProvider.autoDispose<List<LateEntryItem>>(
  (ref) => ref.watch(requestDataSourceProvider).getLateEntriesToResolve(),
);

final allResignationsProvider = FutureProvider.autoDispose<List<ResignationItem>>(
  (ref) => ref.watch(requestDataSourceProvider).getAllResignations(),
);

final orgLeaveRequestsProvider = FutureProvider.autoDispose<List<LeaveRequest>>(
  (ref) => ref.watch(requestDataSourceProvider).getOrgLeaveRequests(),
);

final departmentOptionsProvider = FutureProvider.autoDispose<List<DropdownOptionModel>>(
  (ref) => ref.watch(extrasDataSourceProvider).getOptions('departments'),
);

final analyticsSummaryProvider = FutureProvider.autoDispose.family<AnalyticsSummary, int?>(
  (ref, deptId) => ref.watch(dashboardDataSourceProvider).getAnalyticsSummary(departmentId: deptId),
);

/// Key: "chartType|departmentId|year" (0 = all).
final analyticsChartProvider = FutureProvider.autoDispose.family<List<ChartPoint>, String>((ref, key) {
  final p = key.split('|');
  final dept = int.tryParse(p[1]) ?? 0;
  final year = int.tryParse(p[2]) ?? 0;
  return ref.watch(dashboardDataSourceProvider).getChart(
        p[0],
        departmentId: dept == 0 ? null : dept,
        year: year == 0 ? null : year,
      );
});

final ticketActivityProvider = FutureProvider.autoDispose.family<TicketActivity, int>(
  (ref, id) => ref.watch(extrasDataSourceProvider).getTicketActivity(id),
);

final ticketStatusOptionsProvider = FutureProvider.autoDispose<List<DropdownOptionModel>>(
  (ref) => ref.watch(extrasDataSourceProvider).getOptions('ticketstatus'),
);

final jobOpeningsProvider = FutureProvider.autoDispose<List<JobOpening>>(
  (ref) => ref.watch(extrasDataSourceProvider).getJobOpenings(),
);

final jobCandidatesProvider = FutureProvider.autoDispose.family<List<JobCandidate>, String>(
  (ref, uniqueId) => ref.watch(extrasDataSourceProvider).getJobCandidates(uniqueId),
);

final offersProvider = FutureProvider.autoDispose<List<OfferItem>>(
  (ref) => ref.watch(extrasDataSourceProvider).getOffers(),
);

final orgChartProvider = FutureProvider.autoDispose.family<OrgNode?, int>(
  (ref, id) => ref.watch(extrasDataSourceProvider).getOrgChart(id),
);

final weekOffsProvider = FutureProvider.autoDispose<List<WeekOffRule>>(
  (ref) => ref.watch(extrasDataSourceProvider).getWeekOffs(),
);

final myTimesheetsProvider = FutureProvider.autoDispose<List<TimesheetItem>>(
  (ref) => ref.watch(extrasDataSourceProvider).getMyTimesheets(),
);

// ============ Navigation ============

/// Bumped by pull-to-refresh on Home; every dashboard widget host re-fetches its data.
final dashboardRefreshProvider = StateProvider<int>((ref) => 0);

/// Key of the selected bottom-nav tab: home | leave | approvals | alerts | profile.
final homeTabProvider = StateProvider<String>((ref) => 'home');
