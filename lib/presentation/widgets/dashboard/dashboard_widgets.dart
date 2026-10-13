import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/dashboard_models.dart';
import '../../../data/models/extras_models.dart';
import '../../../data/models/work_models.dart';
import '../../providers/checkin_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../screens/attendance/my_attendance_screen.dart';
import '../../screens/dashboard/holidays_screen.dart';
import '../../screens/assets/my_assets_screen.dart';
import '../../screens/feed/feed_screen.dart';
import '../../screens/helpdesk/ticket_list_screen.dart';
import '../../screens/learning/my_learning_screen.dart';
import '../../screens/payslips/payslips_screen.dart';
import '../../screens/recognition/recognition_screen.dart';
import '../../screens/surveys/surveys_screen.dart';
import '../../navigation/app_menu.dart';
import '../../screens/analytics/hr_analytics_screen.dart';
import '../../screens/approvals/approvals_extra.dart';
import '../../screens/calendar/calendar_screen.dart';
import '../../screens/finance/my_finance_screen.dart';
import '../../screens/leave/comp_off_screen.dart';
import '../../screens/recruitment/recruitment_screen.dart';
import '../../screens/skills/my_skills_screen.dart';
import '../../screens/performance/performance_screen.dart';
import '../../screens/resignation/resignation_screen.dart';
import '../../screens/todo/todo_screen.dart';
import '../../screens/timesheet/timesheet_entry_screen.dart';
import '../../screens/requests/requests_screen.dart';
import '../common/async_value_view.dart';
import '../common/chart_bars.dart';
import '../common/ui_helpers.dart';
import 'check_in_card.dart';

/// Builds the body of one dashboard widget. The host supplies the title chrome.
typedef WidgetBodyBuilder = Widget Function(BuildContext context, WidgetRef ref);

/// A registry entry. [bare] widgets draw their own card (no title chrome).
class WidgetSpec {
  final WidgetBodyBuilder body;
  final bool bare;

  /// Providers to invalidate when the widget is refreshed (pull-to-refresh / timer).
  final List<ProviderOrFamily> Function() providers;

  const WidgetSpec({required this.body, required this.providers, this.bare = false});
}

// ---------------------------------------------------------------------------
// Registry: widget id (server catalogue) -> Flutter widget.
// An id the server sends that is missing here is skipped, never rendered broken.
// Having an entry here is not permission to show it: the layout response is
// the only source of what this user gets.
// ---------------------------------------------------------------------------

const _countTypes = <String, ({String type, IconData icon, Color color})>{
  'counts.employees': (type: 'employees', icon: Icons.people_alt_outlined, color: Color(0xFF5C6BC0)),
  'counts.checkins-today': (type: 'employeeattendance', icon: Icons.how_to_reg_outlined, color: Color(0xFF26A69A)),
  'counts.pending-approvals': (type: 'pendingapprovals', icon: Icons.pending_actions_outlined, color: Color(0xFFFF9800)),
  'counts.tickets.mine': (type: 'mytickets', icon: Icons.confirmation_number_outlined, color: Color(0xFF42A5F5)),
  'counts.leaves.mine': (type: 'myleaverequests', icon: Icons.event_note_outlined, color: Color(0xFF7E57C2)),
  'counts.tickets.all': (type: 'tickets', icon: Icons.support_agent_outlined, color: Color(0xFFEF5350)),
  'counts.tickets.assigned-to-me': (type: 'ticketsassignedtome', icon: Icons.assignment_ind_outlined, color: Color(0xFF29B6F6)),
  'counts.compoff-balance': (type: 'compoffbalance', icon: Icons.more_time_outlined, color: Color(0xFF66BB6A)),
  'counts.inventory-requests': (type: 'invrequests', icon: Icons.inventory_2_outlined, color: Color(0xFF8D6E63)),
  'counts.wfh-today': (type: 'wfhtoday', icon: Icons.home_work_outlined, color: Color(0xFF26C6DA)),
  'counts.new-joinees-month': (type: 'newjoineesmonth', icon: Icons.person_add_alt_outlined, color: Color(0xFFEC407A)),
};

const _chartTypes = <String, String>{
  'chart.attendance-overview': 'attendanceoverview',
  'chart.headcount-trend': 'headcounttrend',
  'chart.leave-by-dept': 'leavebydept',
  'chart.ticket-status': 'ticketstatus',
  'chart.demographics-age': 'age',
  'chart.demographics-gender': 'gender',
  'chart.login-activity': 'loginactivity',
  'chart.demographics-dept': 'departentcountchart',
  'chart.late-arrivals': 'latearrivals',
  'chart.attrition': 'attrition',
  'chart.hiring-funnel': 'hiringfunnel',
  'chart.leave-utilization': 'leaveutilization',
};

WidgetSpec? resolveWidgetSpec(String id) {
  final count = _countTypes[id];
  if (count != null) {
    return WidgetSpec(
      bare: true,
      providers: () => [countWidgetProvider(count.type)],
      body: (c, ref) => _CountTile(type: count.type, icon: count.icon, color: count.color, id: id),
    );
  }

  final chart = _chartTypes[id];
  if (chart != null) {
    return WidgetSpec(
      providers: () => [chartWidgetProvider(chart)],
      body: (c, ref) => _ChartBody(chartType: chart),
    );
  }

  switch (id) {
    case 'att.web-checkin':
      return WidgetSpec(bare: true, providers: () => [], body: (c, ref) => const _CheckInWidget());
    case 'quick-actions':
      return WidgetSpec(bare: true, providers: () => [], body: (c, ref) => const _QuickActions());
    case 'list.approvals-inbox':
      return WidgetSpec(providers: () => [approvalsInboxProvider], body: (c, ref) => const _ApprovalsInboxBody());
    case 'list.team-approvals':
      return WidgetSpec(providers: () => [leaveApprovalsProvider], body: (c, ref) => const _TeamApprovalsBody());
    case 'chart.my-leave-balance':
      return WidgetSpec(providers: () => [leaveBalancesProvider], body: (c, ref) => const _LeaveBalanceBody());
    case 'list.my-recent-leaves':
      return WidgetSpec(providers: () => [myLeaveRequestsProvider], body: (c, ref) => const _RecentLeavesBody());
    case 'feed.announcements':
      return WidgetSpec(providers: () => [feedProvider], body: (c, ref) => const _FeedBody());
    case 'list.today-leave':
      return WidgetSpec(providers: () => [outTodayProvider], body: (c, ref) => const _OutTodayBody());
    case 'perf.my-summary':
      return WidgetSpec(providers: () => [performanceSummaryProvider], body: (c, ref) => const _PerformanceBody());
    case 'list.recent-tickets':
      return WidgetSpec(providers: () => [recentTicketsProvider], body: (c, ref) => const _RecentTicketsBody());
    case 'list.holidays':
      return WidgetSpec(providers: () => [holidaysProvider], body: (c, ref) => const _HolidaysBody());
    case 'people.celebrations':
      return WidgetSpec(providers: () => [peopleWidgetProvider], body: (c, ref) => const _PeopleBody());
    case 'list.my-todos':
      return WidgetSpec(providers: () => [todosWidgetProvider], body: (c, ref) => const _TodosBody(upcoming: false));
    case 'list.todo-upcoming':
      return WidgetSpec(providers: () => [todosWidgetProvider], body: (c, ref) => const _TodosBody(upcoming: true));
  }
  return null;
}

// ---------------------------------------------------------------------------
// Host: title chrome + auto refresh, per the catalogue's refreshSeconds.
// ---------------------------------------------------------------------------

class DashboardWidgetHost extends ConsumerStatefulWidget {
  final String id;
  final String title;
  final WidgetSpec spec;
  final int? refreshSeconds;

  const DashboardWidgetHost({
    super.key,
    required this.id,
    required this.title,
    required this.spec,
    this.refreshSeconds,
  });

  @override
  ConsumerState<DashboardWidgetHost> createState() => _DashboardWidgetHostState();
}

class _DashboardWidgetHostState extends ConsumerState<DashboardWidgetHost> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final s = widget.refreshSeconds;
    if (s != null && s > 0) {
      _timer = Timer.periodic(Duration(seconds: s), (_) {
        if (mounted) _refresh();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refresh() {
    for (final p in widget.spec.providers()) {
      ref.invalidate(p);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(dashboardRefreshProvider, (_, __) => _refresh());
    final body = widget.spec.body(context, ref);
    if (widget.spec.bare) return body;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 10),
          body,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _CountTile extends ConsumerWidget {
  final String id;
  final String type;
  final IconData icon;
  final Color color;

  const _CountTile({required this.id, required this.type, required this.icon, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = ref.watch(dashboardCatalogProvider).valueOrNull?[id]?.title ?? '';
    final value = ref.watch(countWidgetProvider(type));
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      onTap: () => ref.invalidate(countWidgetProvider(type)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                value.when(
                  skipLoadingOnRefresh: true,
                  data: (v) => Text('$v', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  loading: () => const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (_, __) => Icon(Icons.error_outline, size: 20, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One generic renderer covers every catalogue chart type.
class _ChartBody extends ConsumerWidget {
  final String chartType;
  const _ChartBody({required this.chartType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<List<ChartPoint>>(
      compact: true,
      value: ref.watch(chartWidgetProvider(chartType)),
      onRetry: () => ref.invalidate(chartWidgetProvider(chartType)),
      builder: (points) => ChartBars(points: points),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String text;
  const _EmptyNote(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
      );
}

class _CheckInWidget extends ConsumerWidget {
  const _CheckInWidget();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(checkInProvider);
    if (state.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ok = state.errorMessage!.contains('successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.errorMessage!), backgroundColor: ok ? Colors.green : Colors.red),
        );
        ref.read(checkInProvider.notifier).clearError();
      });
    }
    return CheckInCard(
      checkInState: state,
      onCheckIn: () => ref.read(checkInProvider.notifier).checkIn(),
      onCheckOut: () => ref.read(checkInProvider.notifier).checkOut(),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasApprovals = (ref.watch(approvalsInboxProvider).valueOrNull?.items ?? []).isNotEmpty;
    final actions = <({IconData icon, String label, Color color, VoidCallback onTap})>[
      (
        icon: Icons.event_available_outlined,
        label: 'Apply Leave',
        color: const Color(0xFF2196F3),
        onTap: () => ref.read(homeTabProvider.notifier).state = 'leave',
      ),
      (
        icon: Icons.access_time,
        label: 'Attendance',
        color: const Color(0xFF4CAF50),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyAttendanceScreen())),
      ),
      (
        icon: Icons.edit_calendar_outlined,
        label: 'Requests',
        color: const Color(0xFF009688),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestsScreen())),
      ),
      (
        icon: Icons.receipt_long_outlined,
        label: 'Payslips',
        color: const Color(0xFF5C6BC0),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PayslipsScreen())),
      ),
      (
        icon: Icons.campaign_outlined,
        label: 'Posts',
        color: const Color(0xFFEC407A),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedScreen())),
      ),
      (
        icon: Icons.school_outlined,
        label: 'Learning',
        color: const Color(0xFF7E57C2),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyLearningScreen())),
      ),
      (
        icon: Icons.laptop_mac_outlined,
        label: 'My assets',
        color: const Color(0xFF8D6E63),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyAssetsScreen())),
      ),
      (
        icon: Icons.emoji_events_outlined,
        label: 'Recognition',
        color: const Color(0xFFFFA000),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecognitionScreen())),
      ),
      (
        icon: Icons.poll_outlined,
        label: 'Surveys',
        color: const Color(0xFF00ACC1),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SurveysScreen())),
      ),
      (
        icon: Icons.more_time_outlined,
        label: 'Comp-off',
        color: const Color(0xFF66BB6A),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompOffScreen())),
      ),
      (
        icon: Icons.trending_up_rounded,
        label: 'Performance',
        color: const Color(0xFF5C6BC0),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PerformanceScreen())),
      ),
      (
        icon: Icons.checklist_rounded,
        label: 'To-do',
        color: const Color(0xFF26A69A),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TodoScreen())),
      ),
      (
        icon: Icons.exit_to_app_rounded,
        label: 'Resignation',
        color: const Color(0xFF8D6E63),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResignationScreen())),
      ),
      (
        icon: Icons.account_balance_wallet_outlined,
        label: 'My finance',
        color: const Color(0xFF43A047),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyFinanceScreen())),
      ),
      (
        icon: Icons.psychology_alt_outlined,
        label: 'My skills',
        color: const Color(0xFF00897B),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MySkillsScreen())),
      ),
      (
        icon: Icons.calendar_month_outlined,
        label: 'Calendar',
        color: const Color(0xFF5E35B1),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen())),
      ),
      (
        icon: Icons.schedule_outlined,
        label: 'Timesheets',
        color: const Color(0xFF26A69A),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TimesheetEntryScreen())),
      ),
      (
        icon: Icons.support_agent_outlined,
        label: 'Helpdesk',
        color: const Color(0xFFEF5350),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TicketListScreen())),
      ),
      (
        icon: Icons.celebration_outlined,
        label: 'Holidays',
        color: const Color(0xFFFF9800),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HolidaysScreen())),
      ),
      // Admin / HR shortcuts: only when the server's menu grants the module.
      if (menuHas(ref, 'analytics'))
        (
          icon: Icons.insights_rounded,
          label: 'Analytics',
          color: const Color(0xFF3949AB),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrAnalyticsScreen())),
        ),
      if (menuHas(ref, 'leaves/hrApprovals'))
        (
          icon: Icons.fact_check_outlined,
          label: 'HR leave',
          color: const Color(0xFF8E24AA),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrLeaveApprovalsScreen())),
        ),
      if (menuHas(ref, 'jobpost/list') || menuHas(ref, 'inw/list'))
        (
          icon: Icons.work_outline_rounded,
          label: 'Recruitment',
          color: const Color(0xFF00897B),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecruitmentScreen())),
        ),
      if (menuHas(ref, 'resignation/list'))
        (
          icon: Icons.person_off_outlined,
          label: 'Resignations',
          color: const Color(0xFF6D4C41),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResignationApprovalsScreen())),
        ),
      if (hasApprovals)
        (
          icon: Icons.fact_check_outlined,
          label: 'Approvals',
          color: const Color(0xFF7E57C2),
          onTap: () => ref.read(homeTabProvider.notifier).state = 'approvals',
        ),
    ];

    // Four per row; the first seven show, the rest live under "More" so Home stays calm.
    const maxShown = 8;
    final overflow = actions.length > maxShown;
    final shown = overflow ? actions.take(maxShown - 1).toList() : actions;

    Widget tile(IconData icon, String label, Color color, VoidCallback onTap) => InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconBadge(icon: icon, color: color, size: 52),
                const SizedBox(height: 6),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        );

    void openAll() {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheet) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader('All shortcuts'),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.85,
                children: [
                  for (final a in actions)
                    tile(a.icon, a.label, a.color, () {
                      Navigator.pop(sheet);
                      a.onTap();
                    }),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Quick actions'),
        const SizedBox(height: 6),
        SurfaceCard(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.85,
            children: [
              for (final a in shown) tile(a.icon, a.label, a.color, a.onTap),
              if (overflow) tile(Icons.apps_rounded, 'More', const Color(0xFF64748B), openAll),
            ],
          ),
        ),
      ],
    );
  }
}

class _ApprovalsInboxBody extends ConsumerWidget {
  const _ApprovalsInboxBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<ApprovalsInbox>(
      compact: true,
      value: ref.watch(approvalsInboxProvider),
      onRetry: () => ref.invalidate(approvalsInboxProvider),
      builder: (inbox) {
        final rows = inbox.items.where((i) => i.count > 0).toList();
        if (rows.isEmpty) return const _EmptyNote('Nothing is waiting on you.');
        return Column(
          children: [
            for (final r in rows)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(r.label),
                subtitle: Text(r.scope == 'all' ? 'Organisation' : r.scope == 'team' ? 'My team' : 'Mine',
                    style: const TextStyle(fontSize: 11)),
                trailing: StatusChip(label: '${r.count}', color: AppColors.warning),
                onTap: r.type == 'leave' ? () => ref.read(homeTabProvider.notifier).state = 'approvals' : null,
              ),
          ],
        );
      },
    );
  }
}

class _TeamApprovalsBody extends ConsumerWidget {
  const _TeamApprovalsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView(
      compact: true,
      value: ref.watch(leaveApprovalsProvider),
      onRetry: () => ref.invalidate(leaveApprovalsProvider),
      builder: (list) {
        final pending = list.where((a) => a.isPending).take(5).toList();
        if (pending.isEmpty) return const _EmptyNote('No pending leave approvals.');
        return Column(
          children: [
            for (final a in pending)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(a.employeeName),
                subtitle: Text('${a.leaveTypeName} · ${formatDateRange(a.fromDate, a.toDate)}'),
                trailing: Text('${a.noOfDays}d', style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => ref.read(homeTabProvider.notifier).state = 'approvals',
              ),
          ],
        );
      },
    );
  }
}

class _LeaveBalanceBody extends ConsumerWidget {
  const _LeaveBalanceBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView(
      compact: true,
      value: ref.watch(leaveBalancesProvider),
      onRetry: () => ref.invalidate(leaveBalancesProvider),
      builder: (list) {
        if (list.isEmpty) return const _EmptyNote('No leave balances yet.');
        return Column(
          children: [
            for (final b in list)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(b.leaveTypeName, style: const TextStyle(fontSize: 13)),
                        Text('${b.remaining.toStringAsFixed(b.remaining % 1 == 0 ? 0 : 1)} / ${b.total.toStringAsFixed(b.total % 1 == 0 ? 0 : 1)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: b.total <= 0 ? 0 : (b.remaining / b.total).clamp(0, 1),
                        minHeight: 6,
                        backgroundColor: AppColors.primaryContainer,
                        color: AppColors.tertiary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RecentLeavesBody extends ConsumerWidget {
  const _RecentLeavesBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView(
      compact: true,
      value: ref.watch(myLeaveRequestsProvider),
      onRetry: () => ref.invalidate(myLeaveRequestsProvider),
      builder: (list) {
        if (list.isEmpty) return const _EmptyNote('No leave requests yet.');
        return Column(
          children: [
            for (final l in list.take(5))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(l.leaveTypeName),
                subtitle: Text('${formatDateRange(l.fromDate, l.toDate)} · ${l.noOfDays}d'),
                trailing: StatusChip(label: l.statusName, color: leaveStatusColor(l.statusId)),
              ),
          ],
        );
      },
    );
  }
}

class _HolidaysBody extends ConsumerWidget {
  const _HolidaysBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView(
      compact: true,
      value: ref.watch(holidaysProvider),
      onRetry: () => ref.invalidate(holidaysProvider),
      builder: (list) {
        if (list.isEmpty) return const _EmptyNote('No upcoming holidays.');
        return Column(
          children: [
            for (final h in list.take(4))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.celebration_outlined, color: AppColors.warning),
                title: Text(h.name),
                trailing: Text(formatYmd(h.date?.toIso8601String()), style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HolidaysScreen())),
                child: const Text('View all'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PeopleBody extends ConsumerWidget {
  const _PeopleBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<PeopleWidgets>(
      compact: true,
      value: ref.watch(peopleWidgetProvider),
      onRetry: () => ref.invalidate(peopleWidgetProvider),
      builder: (p) {
        if (p.isEmpty) return const _EmptyNote('No celebrations this week.');
        Widget section(String title, IconData icon, List<PeopleItem> items, String Function(PeopleItem) sub) {
          if (items.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 2),
                child: Row(children: [
                  Icon(icon, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
              for (final i in items.take(5))
                ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.primaryContainer,
                    child: Text(i.name.isEmpty ? '?' : i.name[0].toUpperCase(),
                        style: const TextStyle(fontSize: 12, color: AppColors.primary)),
                  ),
                  title: Text(i.name),
                  subtitle: Text(sub(i), style: const TextStyle(fontSize: 11)),
                ),
            ],
          );
        }

        return Column(
          children: [
            section('Birthdays', Icons.cake_outlined, p.birthdays, (i) => i.dateLabel ?? i.dept ?? ''),
            section('Work anniversaries', Icons.workspace_premium_outlined, p.anniversaries,
                (i) => '${i.yearsOfService ?? ''} yrs · ${i.dateLabel ?? ''}'),
            section('New joinees', Icons.waving_hand_outlined, p.newJoinees, (i) => i.dept ?? i.dateLabel ?? ''),
          ],
        );
      },
    );
  }
}

class _TodosBody extends ConsumerWidget {
  final bool upcoming;
  const _TodosBody({required this.upcoming});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<TodoDashboard>(
      compact: true,
      value: ref.watch(todosWidgetProvider),
      onRetry: () => ref.invalidate(todosWidgetProvider),
      builder: (t) {
        final items = upcoming ? t.upcoming : [...t.overdue, ...t.dueToday];
        if (items.isEmpty) return _EmptyNote(upcoming ? 'Nothing coming up.' : 'You are all caught up.');
        return Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TodoScreen())),
                child: const Text('Open list'),
              ),
            ),
            for (final i in items)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: i.isCompleted,
                title: Text(i.title),
                subtitle: Text(
                  i.isOverdue ? 'Overdue · ${formatYmd(i.dueDate)}' : formatYmd(i.dueDate),
                  style: TextStyle(fontSize: 11, color: i.isOverdue ? AppColors.error : null),
                ),
                onChanged: (_) async {
                  await ref.read(dashboardDataSourceProvider).completeTodo(i.id);
                  ref.invalidate(todosWidgetProvider);
                },
              ),
          ],
        );
      },
    );
  }
}

class _FeedBody extends ConsumerWidget {
  const _FeedBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<List<FeedPost>>(
      compact: true,
      value: ref.watch(feedProvider),
      onRetry: () => ref.invalidate(feedProvider),
      builder: (list) {
        if (list.isEmpty) return const _EmptyNote('No announcements.');
        return Column(
          children: [
            for (final p in list.take(3))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(p.header, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(p.plainBody, maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedScreen())),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedScreen())),
                child: const Text('View all'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OutTodayBody extends ConsumerWidget {
  const _OutTodayBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView(
      compact: true,
      value: ref.watch(outTodayProvider),
      onRetry: () => ref.invalidate(outTodayProvider),
      builder: (list) {
        if (list.isEmpty) return const _EmptyNote('Everyone is in today.');
        return Column(
          children: [
            for (final l in list.take(6))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primaryContainer,
                  child: Text(
                    (l.employeeName ?? '?').isEmpty ? '?' : l.employeeName![0].toUpperCase(),
                    style: const TextStyle(fontSize: 12, color: AppColors.primary),
                  ),
                ),
                title: Text(l.employeeName ?? ''),
                subtitle: Text('${l.leaveTypeName} · until ${formatYmd(l.toDate)}'),
              ),
          ],
        );
      },
    );
  }
}

class _RecentTicketsBody extends ConsumerWidget {
  const _RecentTicketsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView(
      compact: true,
      value: ref.watch(recentTicketsProvider),
      onRetry: () => ref.invalidate(recentTicketsProvider),
      builder: (list) {
        if (list.isEmpty) return const _EmptyNote('No tickets.');
        return Column(
          children: [
            for (final t in list)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(t.subject ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(t.uniqueNo ?? ''),
                trailing: StatusChip(label: t.ticketStatusName ?? '', color: AppColors.info),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TicketListScreen())),
                child: const Text('View all'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PerformanceBody extends ConsumerWidget {
  const _PerformanceBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<PerformanceSummary?>(
      compact: true,
      value: ref.watch(performanceSummaryProvider),
      onRetry: () => ref.invalidate(performanceSummaryProvider),
      builder: (p) {
        if (p == null) return const _EmptyNote('No active performance cycle.');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(p.cycleName, style: const TextStyle(fontWeight: FontWeight.w600))),
              if (p.cycleStatusName.isNotEmpty) StatusChip(label: p.cycleStatusName, color: AppColors.info),
            ]),
            const SizedBox(height: 10),
            Text('Goals approved: ${p.approvedGoals} / ${p.totalGoals}', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: p.totalGoals == 0 ? 0 : p.approvedGoals / p.totalGoals,
                minHeight: 6,
                backgroundColor: AppColors.primaryContainer,
                color: AppColors.tertiary,
              ),
            ),
            const SizedBox(height: 10),
            Text('My review: ${p.reviewLabel}', style: const TextStyle(fontSize: 13)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PerformanceScreen())),
                child: const Text('Open performance'),
              ),
            ),
            if (p.nextDeadline != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${p.nextDeadlineLabel}: ${formatYmd(p.nextDeadline, withYear: true)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ),
          ],
        );
      },
    );
  }
}
