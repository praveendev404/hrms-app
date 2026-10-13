import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/user_profile_provider.dart';
import '../screens/assets/my_assets_screen.dart';
import '../screens/attendance/attendance_screen.dart';
import '../screens/attendance/my_attendance_screen.dart';
import '../screens/dashboard/holidays_screen.dart';
import '../screens/employee/employee_list_screen.dart';
import '../screens/feed/feed_screen.dart';
import '../screens/helpdesk/ticket_list_screen.dart';
import '../screens/learning/my_learning_screen.dart';
import '../screens/login/login_screen.dart';
import '../screens/payslips/payslips_screen.dart';
import '../screens/recognition/recognition_screen.dart';
import '../screens/requests/requests_screen.dart';
import '../screens/surveys/surveys_screen.dart';
import '../screens/analytics/hr_analytics_screen.dart';
import '../screens/approvals/approvals_extra.dart';
import '../screens/calendar/calendar_screen.dart';
import '../screens/employee/org_chart_screen.dart';
import '../screens/finance/my_finance_screen.dart';
import '../screens/leave/comp_off_screen.dart';
import '../screens/onboarding/onboarding_tasks_screen.dart';
import '../screens/skills/my_skills_screen.dart';
import '../screens/performance/performance_screen.dart';
import '../screens/recruitment/recruitment_screen.dart';
import '../screens/resignation/resignation_screen.dart';
import '../screens/todo/todo_screen.dart';
import '../screens/timesheet/timesheet_entry_screen.dart';
import '../../core/theme/app_colors.dart';

/// Key of the shell Scaffold, so any tab's app bar can open the drawer.
final GlobalKey<ScaffoldState> shellScaffoldKey = GlobalKey<ScaffoldState>();

/// Hamburger button for tab app bars.
class MenuButton extends StatelessWidget {
  const MenuButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        icon: const Icon(Icons.menu),
        tooltip: 'Menu',
        onPressed: () => shellScaffoldKey.currentState?.openDrawer(),
      );
}

/// A mobile destination for a web nav URL.
class _Destination {
  final IconData icon;

  /// Opens the destination. Tab destinations switch tabs instead of pushing.
  final void Function(BuildContext context, WidgetRef ref) open;

  /// Tab key if this destination is a bottom-nav tab ('approvals' only exists when the
  /// server's approvals inbox has rows, so the drawer hides it otherwise).
  final String? tab;

  const _Destination(this.icon, this.open, {this.tab});
}

void _push(BuildContext c, Widget w) => Navigator.push(c, MaterialPageRoute(builder: (_) => w));

_Destination _tab(IconData icon, String key) =>
    _Destination(icon, (c, ref) => ref.read(homeTabProvider.notifier).state = key, tab: key);

/// Web nav URL (from the server menu) -> mobile screen. A URL without an entry has no
/// mobile screen and is simply not listed; the server still decides who sees what.
final Map<String, _Destination> _destinations = {
  'dashboard': _tab(Icons.home_outlined, 'home'),
  'leaves': _tab(Icons.event_note_outlined, 'leave'),
  'leaves/list': _tab(Icons.event_note_outlined, 'leave'),
  'leaves/approvals': _tab(Icons.fact_check_outlined, 'approvals'),
  'leaves/hrApprovals': _Destination(Icons.fact_check_outlined, (c, r) => _push(c, const HrLeaveApprovalsScreen())),
  'timesheet/team': _tab(Icons.fact_check_outlined, 'approvals'),
  'timesheet/all': _tab(Icons.fact_check_outlined, 'approvals'),
  'leaves/comp-off': _tab(Icons.fact_check_outlined, 'approvals'),
  'timemgmt': _Destination(Icons.access_time, (c, r) => _push(c, const MyAttendanceScreen())),
  'timemgmt/my-monthly-attendence': _Destination(Icons.calendar_month_outlined, (c, r) => _push(c, const MyAttendanceScreen())),
  'timemgmt/all-attendance': _Destination(Icons.groups_outlined, (c, r) => _push(c, const AttendanceScreen())),
  'timemgmt/regularizeapprovals': _tab(Icons.fact_check_outlined, 'approvals'),
  'timemgmt/wfh-requests/mine': _Destination(Icons.home_work_outlined, (c, r) => _push(c, const RequestsScreen(initialTab: 1))),
  'timemgmt/wfh-requests/team': _tab(Icons.fact_check_outlined, 'approvals'),
  'timemgmt/wfh-requests/all': _tab(Icons.fact_check_outlined, 'approvals'),
  'timesheet/my': _Destination(Icons.schedule_outlined, (c, r) => _push(c, const TimesheetEntryScreen())),
  'performance/my-goals': _Destination(Icons.flag_outlined, (c, r) => _push(c, const PerformanceScreen())),
  'performance/self-assessment': _Destination(Icons.rate_review_outlined, (c, r) => _push(c, const PerformanceScreen(initialTab: 1))),
  'performance/my-reviews': _Destination(Icons.rate_review_outlined, (c, r) => _push(c, const PerformanceScreen(initialTab: 1))),
  'performance/feedback': _Destination(Icons.forum_outlined, (c, r) => _push(c, const PerformanceScreen(initialTab: 2))),
  'performance/received-feedback': _Destination(Icons.forum_outlined, (c, r) => _push(c, const PerformanceScreen(initialTab: 2))),
  'resignation/add': _Destination(Icons.exit_to_app_rounded, (c, r) => _push(c, const ResignationScreen())),
  'resignation/list': _Destination(Icons.exit_to_app_rounded, (c, r) => _push(c, const ResignationApprovalsScreen())),
  'todo': _Destination(Icons.checklist_rounded, (c, r) => _push(c, const TodoScreen())),
  'todo/list': _Destination(Icons.checklist_rounded, (c, r) => _push(c, const TodoScreen())),
  'analytics': _Destination(Icons.insights_rounded, (c, r) => _push(c, const HrAnalyticsScreen())),
  'jobpost/list': _Destination(Icons.work_outline_rounded, (c, r) => _push(c, const RecruitmentScreen())),
  'inw/list': _Destination(Icons.work_outline_rounded, (c, r) => _push(c, const RecruitmentScreen())),
  'inw/candidates': _Destination(Icons.groups_outlined, (c, r) => _push(c, const RecruitmentScreen())),
  'recruitment/offers': _Destination(Icons.mail_outline_rounded, (c, r) => _push(c, const RecruitmentScreen(initialTab: 1))),
  'calendar': _Destination(Icons.calendar_month_outlined, (c, r) => _push(c, const CalendarScreen())),
  'orgchart': _Destination(Icons.account_tree_outlined, (c, r) => _push(c, const OrgChartScreen())),
  'tax/form16/my': _Destination(Icons.description_outlined, (c, r) => _push(c, const MyFinanceScreen())),
  'myfinance/summary': _Destination(Icons.account_balance_wallet_outlined, (c, r) => _push(c, const MyFinanceScreen())),
  'loans/my-loans': _Destination(Icons.account_balance_wallet_outlined, (c, r) => _push(c, const MyFinanceScreen())),
  'skill-matrix': _Destination(Icons.psychology_alt_outlined, (c, r) => _push(c, const MySkillsScreen())),
  'onboarding/my-tasks': _Destination(Icons.assignment_turned_in_outlined, (c, r) => _push(c, const OnboardingTasksScreen())),
  'leaves/my-comp-off': _Destination(Icons.more_time_outlined, (c, r) => _push(c, const CompOffScreen())),
  'payroll/payslips': _Destination(Icons.receipt_long_outlined, (c, r) => _push(c, const PayslipsScreen())),
  'employee/list': _Destination(Icons.people_alt_outlined, (c, r) => _push(c, const EmployeeListScreen())),
  'ticket/list': _Destination(Icons.support_agent_outlined, (c, r) => _push(c, const TicketListScreen())),
  'feed/view': _Destination(Icons.campaign_outlined, (c, r) => _push(c, const FeedScreen())),
  'asset/myassets': _Destination(Icons.laptop_mac_outlined, (c, r) => _push(c, const MyAssetsScreen())),
  'learning/my-courses': _Destination(Icons.school_outlined, (c, r) => _push(c, const MyLearningScreen())),
  'recognition/wall': _Destination(Icons.emoji_events_outlined, (c, r) => _push(c, const RecognitionScreen())),
  'recognition/my-recognitions': _Destination(Icons.emoji_events_outlined, (c, r) => _push(c, const RecognitionScreen())),
  'recognition/leaderboard': _Destination(Icons.leaderboard_outlined, (c, r) => _push(c, const RecognitionScreen())),
  'pulse-survey/my-surveys': _Destination(Icons.poll_outlined, (c, r) => _push(c, const SurveysScreen())),
  'holiday': _Destination(Icons.celebration_outlined, (c, r) => _push(c, const HolidaysScreen())),
};

/// Whether the server's menu for this user contains [navUrl] (used to reveal admin actions).
bool menuHas(WidgetRef ref, String navUrl) {
  final items = ref.watch(userProfileProvider).profile?.additionalData?['menuItems'];
  if (items is! List) return false;
  for (final m in items.whereType<Map>()) {
    final subs = m['lstSubMenuItems'];
    if (subs is List && subs.whereType<Map>().any((s) => s['navUrl'] == navUrl)) return true;
  }
  return false;
}

/// Opens the mobile screen for a web route such as "/leaves/approvals/12" (the form
/// notifications carry). Returns false when the route has no mobile equivalent.
bool openWebRoute(BuildContext context, WidgetRef ref, String? link) {
  if (link == null || link.isEmpty) return false;
  var path = link.split('?').first.trim().replaceFirst(RegExp(r'^/+'), '');
  while (path.isNotEmpty) {
    final dest = _destinations[path];
    if (dest != null) {
      dest.open(context, ref);
      return true;
    }
    final i = path.lastIndexOf('/');
    if (i < 0) break;
    path = path.substring(0, i);
  }
  return false;
}

class _Entry {
  final String text;
  final String navUrl;
  final _Destination dest;
  const _Entry(this.text, this.navUrl, this.dest);
}

class _Section {
  final String title;
  final List<_Entry> entries;
  const _Section(this.title, this.entries);
}

/// Builds sections from the server's menu (profile.menuItems), keeping only the entries
/// that have a mobile destination. Duplicate destinations within a section collapse.
List<_Section> _sectionsFrom(dynamic menuItems, {required bool approvalsAvailable}) {
  if (menuItems is! List) return const [];
  final mains = menuItems.whereType<Map>().toList()
    ..sort((a, b) => ((a['orderId'] as num?) ?? 0).compareTo((b['orderId'] as num?) ?? 0));

  final sections = <_Section>[];
  for (final m in mains) {
    final subs = (m['lstSubMenuItems'] as List?)?.whereType<Map>().toList() ?? [];
    subs.sort((a, b) => ((a['orderId'] as num?) ?? 0).compareTo((b['orderId'] as num?) ?? 0));

    final seen = <String>{};
    final entries = <_Entry>[];
    for (final s in subs) {
      final url = (s['navUrl'] ?? '').toString();
      final dest = _destinations[url];
      if (dest == null) continue;
      if (dest.tab == 'approvals' && !approvalsAvailable) continue;
      final text = (s['menuText'] ?? url).toString();
      if (!seen.add('${dest.tab ?? ''}|$text')) continue;
      entries.add(_Entry(text, url, dest));
    }
    if (entries.isNotEmpty) sections.add(_Section((m['menuText'] ?? '').toString(), entries));
  }
  return sections;
}

/// The navigation drawer, driven by the menu the server returns for this user's role.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(authProvider.notifier).logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _go(BuildContext context, WidgetRef ref, _Destination d) {
    Navigator.pop(context); // close drawer
    d.open(context, ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).profile;
    final approvals = (ref.watch(approvalsInboxProvider).valueOrNull?.items ?? []).isNotEmpty;
    final sections = _sectionsFrom(profile?.additionalData?['menuItems'], approvalsAvailable: approvals);

    final fullName = [profile?.firstName, profile?.lastName].where((s) => (s ?? '').isNotEmpty).join(' ');

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)]),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white,
                    child: Text(
                      fullName.isEmpty ? '?' : fullName[0].toUpperCase(),
                      style: const TextStyle(fontSize: 22, color: AppColors.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(fullName.isEmpty ? 'Welcome' : fullName,
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                  if ((profile?.designation ?? '').isNotEmpty)
                    Text(profile!.designation!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Always present: the app's own tabs and personal tools.
                  ListTile(
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: const Text('My calendar'),
                    onTap: () => _go(context, ref, _destinations['calendar']!),
                  ),
                  ListTile(
                    leading: const Icon(Icons.account_tree_outlined),
                    title: const Text('Org chart'),
                    onTap: () => _go(context, ref, _destinations['orgchart']!),
                  ),
                  ListTile(
                    leading: const Icon(Icons.notifications_none_outlined),
                    title: const Text('Notifications'),
                    onTap: () => _go(context, ref, _tab(Icons.notifications_none_outlined, 'alerts')),
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('My profile'),
                    onTap: () => _go(context, ref, _tab(Icons.person_outline, 'profile')),
                  ),
                  if (sections.isEmpty && profile != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('No other modules are available for your role on mobile.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ),
                  for (final s in sections) ...[
                    const Divider(height: 8),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                      child: Text(s.title.toUpperCase(),
                          style: TextStyle(fontSize: 11, letterSpacing: 0.6, color: Colors.grey.shade600)),
                    ),
                    for (final e in s.entries)
                      ListTile(
                        dense: true,
                        leading: Icon(e.dest.icon, size: 22),
                        title: Text(e.text),
                        onTap: () => _go(context, ref, e.dest),
                      ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text('Logout', style: TextStyle(color: AppColors.error)),
              onTap: () => _logout(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
