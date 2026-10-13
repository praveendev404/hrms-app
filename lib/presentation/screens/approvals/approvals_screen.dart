import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../navigation/app_menu.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/leave_models.dart';
import '../../../data/models/request_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/common/async_value_view.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/ui_helpers.dart';
import 'approvals_extra.dart';

/// Approvals tab: what is waiting on me (server inbox) + act on leave approvals.
class ApprovalsScreen extends ConsumerWidget {
  const ApprovalsScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(approvalsInboxProvider);
    ref.invalidate(leaveApprovalsProvider);
    ref.invalidate(wfhApprovalsProvider);
    ref.invalidate(regularizationsProvider);
    ref.invalidate(timesheetsToReviewProvider);
    ref.invalidate(compOffsToReviewProvider);
    ref.invalidate(lateEntriesProvider);
    await ref.read(leaveApprovalsProvider.future);
  }

  Future<void> _act(BuildContext context, WidgetRef ref, LeaveApproval a, {required bool approve}) async {
    String? reason;
    if (!approve) {
      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Reject leave'),
          content: TextField(
            controller: ctrl,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Reason (optional)'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Back')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Reject')),
          ],
        ),
      );
      reason = ctrl.text.trim();
      ctrl.dispose();
      if (ok != true) return;
    }

    try {
      final r = await ref.read(leaveDataSourceProvider).actOnApprovals(
            [a.id],
            approve ? LeaveStatus.approved : LeaveStatus.rejected,
            reason: reason,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(r.message.isNotEmpty ? r.message : (r.success ? 'Done' : 'Action failed')),
          backgroundColor: r.success ? Colors.green : Colors.red,
        ));
      }
      ref.invalidate(leaveApprovalsProvider);
      ref.invalidate(approvalsInboxProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AsyncValueView.messageOf(e)),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(approvalsInboxProvider).valueOrNull;
    final types = (inbox?.items ?? []).map((i) => i.type).toSet();
    final approvals = ref.watch(leaveApprovalsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(leading: const MenuButton(), title: const Text('Approvals')),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (inbox != null && inbox.items.any((i) => i.count > 0)) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final i in inbox.items.where((i) => i.count > 0))
                    Chip(
                      avatar: CircleAvatar(
                        backgroundColor: AppColors.warning,
                        child: Text('${i.count}', style: const TextStyle(fontSize: 11, color: Colors.white)),
                      ),
                      label: Text(i.label),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              const SizedBox(height: 16),
            ],
            const SectionHeader('Leave requests'),
            const SizedBox(height: 10),
            AsyncValueView<List<LeaveApproval>>(
              value: approvals,
              onRetry: () => ref.invalidate(leaveApprovalsProvider),
              builder: (list) {
                final pending = list.where((a) => a.isPending).toList();
                if (pending.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: EmptyStateWidget(
                      title: 'All caught up',
                      subtitle: 'No leave requests are waiting for you.',
                      icon: Icons.task_alt_outlined,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final a in pending)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                UserAvatar(name: a.employeeName, radius: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(a.employeeName.trim(),
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                ),
                                StatusChip(label: '${a.noOfDays} day(s)', color: AppColors.primary),
                              ]),
                              const SizedBox(height: 4),
                              Text('${a.leaveTypeName} · ${formatDateRange(a.fromDate, a.toDate)}',
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                              if ((a.reason ?? '').isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(a.reason!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton(
                                    onPressed: () => _act(context, ref, a, approve: false),
                                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                                    child: const Text('Reject'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () => _act(context, ref, a, approve: true),
                                    child: const Text('Approve'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            if (types.contains('wfh')) ...[
              const SizedBox(height: 24),
              const Text('Work from home', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              const _WfhApprovals(),
            ],
            if (types.contains('regularization')) ...[
              const SizedBox(height: 24),
              const Text('Attendance regularization', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              const _RegularizeApprovals(),
            ],
            if (types.contains('timesheet')) ...[
              const SizedBox(height: 24),
              const SectionHeader('Timesheets'),
              const SizedBox(height: 10),
              const TimesheetApprovals(),
            ],
            if (types.contains('compoff')) ...[
              const SizedBox(height: 24),
              const SectionHeader('Comp-off'),
              const SizedBox(height: 10),
              const CompOffApprovals(),
            ],
            if (types.contains('late-entry')) ...[
              const SizedBox(height: 24),
              const SectionHeader('Late arrivals'),
              const SizedBox(height: 10),
              const LateEntryApprovals(),
            ],
            if (types.any((t) => !const {'leave', 'wfh', 'regularization', 'timesheet', 'compoff', 'late-entry'}.contains(t))) ...[
              const SizedBox(height: 24),
              Text(
                'Other approvals (such as tickets) are handled on the web for now.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<String?> _askReason(BuildContext context, String title) async {
  final ctrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(controller: ctrl, maxLines: 3, decoration: const InputDecoration(hintText: 'Reason (optional)')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Back')),
        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Reject')),
      ],
    ),
  );
  final text = ctrl.text.trim();
  ctrl.dispose();
  return ok == true ? text : null;
}

void _report(BuildContext context, ActionResult r) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(r.message.isNotEmpty ? r.message : (r.success ? 'Done' : 'Action failed')),
    backgroundColor: r.success ? Colors.green : Colors.red,
  ));
}

class _DecisionButtons extends StatelessWidget {
  final VoidCallback onReject;
  final VoidCallback onApprove;
  const _DecisionButtons({required this.onReject, required this.onApprove});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: onReject,
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Reject'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(onPressed: onApprove, child: const Text('Approve')),
      ],
    );
  }
}

class _WfhApprovals extends ConsumerWidget {
  const _WfhApprovals();

  Future<void> _act(BuildContext context, WidgetRef ref, WfhItem w, bool approve) async {
    String? remarks;
    if (!approve) {
      remarks = await _askReason(context, 'Reject work from home');
      if (remarks == null) return;
    }
    try {
      final r = await ref
          .read(requestDataSourceProvider)
          .setWfhStatus(w.id, approve ? WfhStatus.approved : WfhStatus.rejected, remarks: remarks);
      if (context.mounted) _report(context, r);
      ref.invalidate(wfhApprovalsProvider);
      ref.invalidate(approvalsInboxProvider);
    } catch (e) {
      if (context.mounted) _report(context, ActionResult(false, AsyncValueView.messageOf(e)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<List<WfhItem>>(
      compact: true,
      value: ref.watch(wfhApprovalsProvider),
      onRetry: () => ref.invalidate(wfhApprovalsProvider),
      builder: (list) {
        if (list.isEmpty) return Text('Nothing pending.', style: TextStyle(color: Colors.grey.shade600));
        return Column(
          children: [
            for (final w in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(w.empName.trim(), style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(formatDateRange(w.fromDate, w.toDate), style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                      if ((w.reason ?? '').isNotEmpty)
                        Text(w.reason!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      const SizedBox(height: 8),
                      _DecisionButtons(
                        onReject: () => _act(context, ref, w, false),
                        onApprove: () => _act(context, ref, w, true),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RegularizeApprovals extends ConsumerWidget {
  const _RegularizeApprovals();

  Future<void> _act(BuildContext context, WidgetRef ref, RegularizeItem item, bool approve) async {
    String? remarks;
    if (!approve) {
      remarks = await _askReason(context, 'Reject regularization');
      if (remarks == null) return;
    }
    try {
      final r = await ref.read(requestDataSourceProvider).setRegularizationStatus(
            item.id,
            approve ? RegularizeStatus.approved : RegularizeStatus.rejected,
            remarks: remarks,
          );
      if (context.mounted) _report(context, r);
      ref.invalidate(regularizationsProvider);
      ref.invalidate(approvalsInboxProvider);
    } catch (e) {
      if (context.mounted) _report(context, ActionResult(false, AsyncValueView.messageOf(e)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<List<RegularizeItem>>(
      compact: true,
      value: ref.watch(regularizationsProvider),
      onRetry: () => ref.invalidate(regularizationsProvider),
      builder: (all) {
        final list = all.where((r) => r.isPending).toList();
        if (list.isEmpty) return Text('Nothing pending.', style: TextStyle(color: Colors.grey.shade600));
        return Column(
          children: [
            for (final r in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.empName.trim(), style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('${r.typeName} · ${formatYmd(r.date, withYear: true)}',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                      if (r.inTime != null || r.outTime != null)
                        Text('In ${r.inTime ?? '--'}  ·  Out ${r.outTime ?? '--'}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      if ((r.notes ?? '').isNotEmpty)
                        Text(r.notes!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      const SizedBox(height: 8),
                      _DecisionButtons(
                        onReject: () => _act(context, ref, r, false),
                        onApprove: () => _act(context, ref, r, true),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
