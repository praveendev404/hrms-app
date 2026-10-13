// Wire models for the server-driven dashboard (api/v1/dashboard, api/v1/counts).

class DashboardLayoutItem {
  final String id;
  final int w;
  final int h;

  const DashboardLayoutItem({required this.id, required this.w, required this.h});

  factory DashboardLayoutItem.fromJson(Map<String, dynamic> j) => DashboardLayoutItem(
        id: j['id'] as String? ?? '',
        w: (j['w'] as num?)?.toInt() ?? 12,
        h: (j['h'] as num?)?.toInt() ?? 1,
      );
}

/// Ordered widgets the server decided this user may see.
class DashboardLayout {
  final List<DashboardLayoutItem> items;
  const DashboardLayout(this.items);

  factory DashboardLayout.fromJson(Map<String, dynamic> j) => DashboardLayout(
        (j['items'] as List<dynamic>? ?? [])
            .map((e) => DashboardLayoutItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class DashboardCatalogItem {
  final String id;
  final String title;
  final String? description;
  final String category;
  final int? refreshSeconds;

  const DashboardCatalogItem({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    this.refreshSeconds,
  });

  factory DashboardCatalogItem.fromJson(Map<String, dynamic> j) => DashboardCatalogItem(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        description: j['description'] as String?,
        category: j['category']?.toString() ?? '',
        refreshSeconds: (j['refreshSeconds'] as num?)?.toInt(),
      );
}

class ChartPoint {
  final String label;
  final double value;
  const ChartPoint(this.label, this.value);

  factory ChartPoint.fromJson(Map<String, dynamic> j) =>
      ChartPoint(j['label']?.toString() ?? '', (j['value'] as num?)?.toDouble() ?? 0);
}

class PeopleItem {
  final String name;
  final String? profilePic;
  final String? dept;
  final String? dateLabel;
  final int? yearsOfService;

  const PeopleItem({required this.name, this.profilePic, this.dept, this.dateLabel, this.yearsOfService});

  factory PeopleItem.fromJson(Map<String, dynamic> j) => PeopleItem(
        name: j['name']?.toString() ?? '',
        profilePic: j['profilePic'] as String?,
        dept: j['dept'] as String?,
        dateLabel: j['dateLabel'] as String?,
        yearsOfService: (j['yearsOfService'] as num?)?.toInt(),
      );
}

class PeopleWidgets {
  final List<PeopleItem> birthdays;
  final List<PeopleItem> anniversaries;
  final List<PeopleItem> newJoinees;

  const PeopleWidgets({this.birthdays = const [], this.anniversaries = const [], this.newJoinees = const []});

  bool get isEmpty => birthdays.isEmpty && anniversaries.isEmpty && newJoinees.isEmpty;

  factory PeopleWidgets.fromJson(Map<String, dynamic> j) {
    List<PeopleItem> parse(String k) => (j[k] as List<dynamic>? ?? [])
        .map((e) => PeopleItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return PeopleWidgets(
      birthdays: parse('birthdays'),
      anniversaries: parse('anniversaries'),
      newJoinees: parse('newJoinees'),
    );
  }
}

class ApprovalsInboxItem {
  final String type;
  final String label;
  final int count;
  final String scope;

  const ApprovalsInboxItem({required this.type, required this.label, required this.count, required this.scope});

  factory ApprovalsInboxItem.fromJson(Map<String, dynamic> j) => ApprovalsInboxItem(
        type: j['type']?.toString() ?? '',
        label: j['label']?.toString() ?? '',
        count: (j['count'] as num?)?.toInt() ?? 0,
        scope: j['scope']?.toString() ?? '',
      );
}

class ApprovalsInbox {
  final List<ApprovalsInboxItem> items;
  final int total;
  const ApprovalsInbox(this.items, this.total);

  factory ApprovalsInbox.fromJson(Map<String, dynamic> j) => ApprovalsInbox(
        (j['items'] as List<dynamic>? ?? [])
            .map((e) => ApprovalsInboxItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        (j['total'] as num?)?.toInt() ?? 0,
      );
}

class TodoItem {
  final int id;
  final String title;
  final String? dueDate;
  final String? dueTime;
  final int? priority;
  final bool isCompleted;
  final bool isOverdue;
  final String? description;
  final int reminderType;

  const TodoItem({
    required this.id,
    required this.title,
    this.dueDate,
    this.dueTime,
    this.priority,
    this.isCompleted = false,
    this.isOverdue = false,
    this.description,
    this.reminderType = 0,
  });

  factory TodoItem.fromJson(Map<String, dynamic> j) => TodoItem(
        id: (j['id'] as num?)?.toInt() ?? 0,
        title: j['title']?.toString() ?? '',
        dueDate: j['dueDate'] as String?,
        dueTime: j['dueTime'] as String?,
        priority: (j['priority'] as num?)?.toInt(),
        isCompleted: j['isCompleted'] as bool? ?? false,
        isOverdue: j['isOverdue'] as bool? ?? false,
        description: j['description'] as String?,
        reminderType: (j['reminderType'] as num?)?.toInt() ?? 0,
      );
}

class TodoDashboard {
  final List<TodoItem> overdue;
  final List<TodoItem> dueToday;
  final List<TodoItem> upcoming;

  const TodoDashboard({this.overdue = const [], this.dueToday = const [], this.upcoming = const []});

  factory TodoDashboard.fromJson(Map<String, dynamic> j) {
    List<TodoItem> parse(String k) => (j[k] as List<dynamic>? ?? [])
        .map((e) => TodoItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return TodoDashboard(overdue: parse('overdue'), dueToday: parse('dueToday'), upcoming: parse('upcoming'));
  }
}

class HolidayItem {
  final String name;
  final DateTime? date;
  const HolidayItem(this.name, this.date);

  factory HolidayItem.fromJson(Map<String, dynamic> j) =>
      HolidayItem(j['name']?.toString() ?? '', DateTime.tryParse(j['date']?.toString() ?? ''));
}

/// Headline HR numbers (api/v1/counts/analytics-summary).
class AnalyticsSummary {
  final int totalEmployees;
  final int newJoinees;
  final int exits;
  final double attritionPercent;
  final int openPositions;
  final int candidates;
  final int leaveDays;
  final int pendingLeave;

  const AnalyticsSummary({
    required this.totalEmployees,
    required this.newJoinees,
    required this.exits,
    required this.attritionPercent,
    required this.openPositions,
    required this.candidates,
    required this.leaveDays,
    required this.pendingLeave,
  });

  factory AnalyticsSummary.fromJson(Map<String, dynamic> raw) {
    // Tolerate either a bare object or one wrapped in { data: ... }.
    final j = raw['totalEmployees'] == null && raw['data'] is Map<String, dynamic>
        ? raw['data'] as Map<String, dynamic>
        : raw;
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return AnalyticsSummary(
      totalEmployees: n('totalEmployees'),
      newJoinees: n('newJoineesThisMonth'),
      exits: n('exitsThisMonth'),
      attritionPercent: (j['attritionRatePercent'] as num?)?.toDouble() ?? 0,
      openPositions: n('openJobPositions'),
      candidates: n('totalCandidatesThisMonth'),
      leaveDays: n('leaveDaysThisMonth'),
      pendingLeave: n('pendingLeaveRequests'),
    );
  }
}
