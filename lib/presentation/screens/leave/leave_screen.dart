import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../navigation/app_menu.dart';

import '../../../core/services/phone_calendar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/leave_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/common/async_value_view.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/ui_helpers.dart';
import 'apply_leave_screen.dart';

/// Leave tab: balances, my requests, apply, cancel.
class LeaveScreen extends ConsumerWidget {
  const LeaveScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(leaveBalancesProvider);
    ref.invalidate(myLeaveRequestsProvider);
    await ref.read(myLeaveRequestsProvider.future);
  }

  Future<void> _apply(BuildContext context, WidgetRef ref) async {
    final applied = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ApplyLeaveScreen()),
    );
    if (applied == true) {
      ref.invalidate(leaveBalancesProvider);
      ref.invalidate(myLeaveRequestsProvider);
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, LeaveRequest l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel leave request?'),
        content: Text('${l.leaveTypeName} · ${formatDateRange(l.fromDate, l.toDate)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cancel request')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final r = await ref.read(leaveDataSourceProvider).cancel(l.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(r.message.isNotEmpty ? r.message : (r.success ? 'Request cancelled' : 'Could not cancel')),
          backgroundColor: r.success ? Colors.green : Colors.red,
        ));
      }
      ref.invalidate(leaveBalancesProvider);
      ref.invalidate(myLeaveRequestsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AsyncValueView.messageOf(e)),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _showDetails(BuildContext context, LeaveRequest l) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(l.leaveTypeName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
              StatusChip(label: l.statusName, color: leaveStatusColor(l.statusId)),
            ]),
            const SizedBox(height: 8),
            Text('${formatDateRange(l.fromDate, l.toDate)}  ·  ${l.noOfDays} day(s)'),
            if ((l.fromDayTypeName ?? '').isNotEmpty || (l.toDayTypeName ?? '').isNotEmpty)
              Text('${l.fromDayTypeName ?? ''} to ${l.toDayTypeName ?? ''}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            if ((l.reason ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Reason', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              Text(l.reason!),
            ],
            if (l.statusId == LeaveStatus.approved)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    final from = DateTime.tryParse(l.fromDate);
                    if (from == null) return;
                    addAllDayToPhoneCalendar(
                      title: l.leaveTypeName.isEmpty ? 'Leave' : l.leaveTypeName,
                      from: from,
                      to: DateTime.tryParse(l.toDate),
                      description: l.reason,
                    );
                  },
                  icon: const Icon(Icons.event_available_outlined, size: 18),
                  label: const Text('Add to phone calendar'),
                ),
              ),
            const SizedBox(height: 14),
            Text('Approval', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            if (l.approvers.isEmpty)
              const Text('No approver assigned.')
            else
              for (final a in l.approvers)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Text(a.name),
                  trailing: Text(a.status, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(leaveBalancesProvider);
    final requests = ref.watch(myLeaveRequestsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(leading: const MenuButton(), title: const Text('Leave')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _apply(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Apply'),
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            const SectionHeader('Balances'),
            const SizedBox(height: 10),
            AsyncValueView<List<LeaveBalance>>(
              compact: true,
              value: balances,
              onRetry: () => ref.invalidate(leaveBalancesProvider),
              builder: (list) {
                if (list.isEmpty) return const Text('No leave balances configured.');
                return SizedBox(
                  height: 128,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final b = list[i];
                      const palette = [
                        AppColors.primary,
                        AppColors.tertiary,
                        Color(0xFFFF9800),
                        Color(0xFFEC407A),
                        Color(0xFF29B6F6),
                      ];
                      final color = palette[i % palette.length];
                      final ratio = b.total <= 0 ? 0.0 : (b.remaining / b.total).clamp(0.0, 1.0).toDouble();
                      String n(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 1);
                      return SizedBox(
                        width: 120,
                        child: SurfaceCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 58,
                                height: 58,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox.expand(
                                      child: CircularProgressIndicator(
                                        value: ratio,
                                        strokeWidth: 6,
                                        strokeCap: StrokeCap.round,
                                        backgroundColor: color.withOpacity(0.15),
                                        color: color,
                                      ),
                                    ),
                                    Text(n(b.remaining), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(b.leaveTypeName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text('of ${n(b.total)} left', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const SectionHeader('My requests'),
            const SizedBox(height: 10),
            AsyncValueView<List<LeaveRequest>>(
              value: requests,
              onRetry: () => ref.invalidate(myLeaveRequestsProvider),
              builder: (list) {
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: EmptyStateWidget(
                      title: 'No leave requests',
                      subtitle: 'Tap Apply to request leave.',
                      icon: Icons.event_busy_outlined,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final l in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SurfaceCard(
                          onTap: () => _showDetails(context, l),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(l.leaveTypeName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ),
                                  StatusChip(label: l.statusName, color: leaveStatusColor(l.statusId)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('${formatDateRange(l.fromDate, l.toDate)}  ·  ${l.noOfDays} day(s)',
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                              if ((l.reason ?? '').isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(l.reason!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              ],
                              if (l.canCancel)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () => _cancel(context, ref, l),
                                    child: const Text('Cancel request'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
