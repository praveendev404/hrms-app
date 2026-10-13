import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/dashboard_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../widgets/common/async_value_view.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/dashboard/dashboard_widgets.dart';
import '../../navigation/app_menu.dart';
import '../approvals/approvals_screen.dart';
import '../leave/leave_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/user_profile_screen.dart';

/// Main shell: bottom navigation + the server-driven home dashboard.
/// Which tabs/widgets exist is decided by the API (approvals inbox, layout).
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _unreadTimer;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(userProfileProvider.notifier).fetchUserProfile());
    // Keep the notification badge fresh.
    _unreadTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) ref.invalidate(unreadNotificationsProvider);
    });
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(homeTabProvider);
    final unread = ref.watch(unreadNotificationsProvider).valueOrNull ?? 0;
    // The approvals tab exists only for users the server says can approve something.
    final showApprovals = (ref.watch(approvalsInboxProvider).valueOrNull?.items ?? []).isNotEmpty;

    final tabs = <({String key, IconData icon, IconData selectedIcon, String label, Widget page, int badge})>[
      (key: 'home', icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Home', page: const _HomeTab(), badge: 0),
      (key: 'leave', icon: Icons.event_note_outlined, selectedIcon: Icons.event_note_rounded, label: 'Leave', page: const LeaveScreen(), badge: 0),
      if (showApprovals)
        (key: 'approvals', icon: Icons.fact_check_outlined, selectedIcon: Icons.fact_check_rounded, label: 'Approvals', page: const ApprovalsScreen(), badge: 0),
      (key: 'alerts', icon: Icons.notifications_none_outlined, selectedIcon: Icons.notifications_rounded, label: 'Alerts', page: const NotificationsScreen(), badge: unread),
      (key: 'profile', icon: Icons.person_outline, selectedIcon: Icons.person_rounded, label: 'Profile', page: const UserProfileScreen(), badge: 0),
    ];

    var index = tabs.indexWhere((t) => t.key == selected);
    if (index < 0) index = 0;

    return Scaffold(
      key: shellScaffoldKey,
      drawer: const AppDrawer(),
      body: IndexedStack(index: index, children: [for (final t in tabs) t.page]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => ref.read(homeTabProvider.notifier).state = tabs[i].key,
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Badge(
                isLabelVisible: t.badge > 0,
                label: Text(t.badge > 99 ? '99+' : '${t.badge}'),
                child: Icon(t.icon),
              ),
              selectedIcon: Badge(
                isLabelVisible: t.badge > 0,
                label: Text(t.badge > 99 ? '99+' : '${t.badge}'),
                child: Icon(t.selectedIcon),
              ),
              label: t.label,
            ),
        ],
      ),
    );
  }
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(dashboardCatalogProvider);
    ref.invalidate(approvalsInboxProvider);
    ref.invalidate(unreadNotificationsProvider);
    ref.invalidate(dashboardLayoutProvider);
    ref.read(dashboardRefreshProvider.notifier).state++;
    await ref.read(dashboardLayoutProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(userProfileProvider).profile?.firstName ?? 'there';
    final layout = ref.watch(dashboardLayoutProvider);
    final catalog = ref.watch(dashboardCatalogProvider).valueOrNull ?? const {};

    final unread = ref.watch(unreadNotificationsProvider).valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        leading: const MenuButton(),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_greeting(), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.textSecondaryLight)),
            Text(name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => ref.read(homeTabProvider.notifier).state = 'alerts',
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 99 ? '99+' : '$unread'),
              child: const Icon(Icons.notifications_none_rounded, size: 26),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: AsyncValueView<DashboardLayout>(
          value: layout,
          onRetry: () => ref.invalidate(dashboardLayoutProvider),
          builder: (l) => _WidgetGrid(items: l.items, catalog: catalog),
        ),
      ),
    );
  }
}

/// Lays the server's ordered widget list out as a flow: narrow widgets
/// (w <= 4 of 12 columns) sit two-up, everything else is full width.
class _WidgetGrid extends StatelessWidget {
  final List<DashboardLayoutItem> items;
  final Map<String, DashboardCatalogItem> catalog;

  const _WidgetGrid({required this.items, required this.catalog});

  @override
  Widget build(BuildContext context) {
    final entries = <({DashboardLayoutItem item, WidgetSpec spec})>[];
    for (final item in items) {
      final spec = resolveWidgetSpec(item.id);
      if (spec != null) entries.add((item: item, spec: spec)); // unknown ids are skipped
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final full = constraints.maxWidth - 32;
        final half = (full - gap) / 2;

        // Count tiles (w <= 3) sit two-up. A tile with no partner, and every chart or list
        // card, takes the full width so the grid never leaves a hole beside a card.
        final widths = List<double>.filled(entries.length, full);
        for (var i = 0; i < entries.length;) {
          final isTile = entries[i].item.w <= 3;
          if (isTile && i + 1 < entries.length && entries[i + 1].item.w <= 3) {
            widths[i] = half;
            widths[i + 1] = half;
            i += 2;
          } else {
            i++;
          }
        }

        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: EmptyStateWidget(
                  title: 'Nothing to show yet',
                  subtitle: 'Your dashboard has no widgets configured.',
                  icon: Icons.dashboard_outlined,
                ),
              )
            else
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var i = 0; i < entries.length; i++)
                    SizedBox(
                      width: widths[i],
                      child: DashboardWidgetHost(
                        key: ValueKey(entries[i].item.id),
                        id: entries[i].item.id,
                        title: catalog[entries[i].item.id]?.title ?? entries[i].item.id,
                        spec: entries[i].spec,
                        refreshSeconds: catalog[entries[i].item.id]?.refreshSeconds,
                      ),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}
