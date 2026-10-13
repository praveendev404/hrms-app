import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/leave_models.dart';
import '../../../data/models/work_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/common/async_value_view.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/ui_helpers.dart';

/// Asks for remarks. Returns null when cancelled, otherwise the (possibly empty) text.
Future<String?> askRemarks(
  BuildContext context, {
  required String title,
  String confirm = 'Confirm',
  bool required = false,
}) async {
  final ctrl = TextEditingController();
  String? error;
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, setState) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: InputDecoration(hintText: required ? 'Reason (required)' : 'Remarks (optional)', errorText: error),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Back')),
          ElevatedButton(
            onPressed: () {
              if (required && ctrl.text.trim().isEmpty) {
                setState(() => error = 'Please enter a reason.');
                return;
              }
              Navigator.pop(d, true);
            },
            child: Text(confirm),
          ),
        ],
      ),
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

void _reportError(BuildContext context, Object e) =>
    _report(context, ActionResult(false, AsyncValueView.messageOf(e)));

class _Buttons extends StatelessWidget {
  final VoidCallback onReject;
  final VoidCallback onApprove;
  final String approveLabel;
  final String rejectLabel;
  const _Buttons({
    required this.onReject,
    required this.onApprove,
    this.approveLabel = 'Approve',
    this.rejectLabel = 'Reject',
  });

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      OutlinedButton(
        onPressed: onReject,
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
        child: Text(rejectLabel),
      ),
      const SizedBox(width: 8),
      ElevatedButton(onPressed: onApprove, child: Text(approveLabel)),
    ]);
  }
}

// ============================================================ timesheets

class TimesheetApprovals extends ConsumerWidget {
  const TimesheetApprovals({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref, TimesheetReviewItem t) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TimesheetReview(sheet: t),
    );
    if (done == true) {
      ref.invalidate(timesheetsToReviewProvider);
      ref.invalidate(approvalsInboxProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<List<TimesheetReviewItem>>(
      compact: true,
      value: ref.watch(timesheetsToReviewProvider),
      onRetry: () => ref.invalidate(timesheetsToReviewProvider),
      builder: (list) {
        if (list.isEmpty) return Text('Nothing pending.', style: TextStyle(color: Colors.grey.shade600));
        return Column(children: [
          for (final t in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SurfaceCard(
                onTap: () => _open(context, ref, t),
                child: Row(children: [
                  UserAvatar(name: t.empName, radius: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.empName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(formatDateRange(t.fromDate, t.toDate), style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                    ]),
                  ),
                  StatusChip(label: '${t.totalHours} h', color: AppColors.primary),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}

class _TimesheetReview extends ConsumerStatefulWidget {
  final TimesheetReviewItem sheet;
  const _TimesheetReview({required this.sheet});

  @override
  ConsumerState<_TimesheetReview> createState() => _TimesheetReviewState();
}

class _TimesheetReviewState extends ConsumerState<_TimesheetReview> {
  bool _busy = false;

  Future<void> _decide(bool approve) async {
    String? remarks = '';
    if (!approve) {
      remarks = await askRemarks(context, title: 'Reject timesheet', confirm: 'Reject', required: true);
      if (remarks == null) return;
    }
    setState(() => _busy = true);
    try {
      final r = await ref.read(requestDataSourceProvider).decideTimesheet(widget.sheet.id, approve: approve, remarks: remarks);
      if (!mounted) return;
      _report(context, r);
      if (r.success) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _reportError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(timesheetLogsProvider(widget.sheet.id));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.sheet.empName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text('${formatDateRange(widget.sheet.fromDate, widget.sheet.toDate)}  ·  ${widget.sheet.totalHours} h  ·  ${widget.sheet.billableHours} h billable',
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 10),
            Flexible(
              child: AsyncValueView<List<WorkLog>>(
                compact: true,
                value: logs,
                onRetry: () => ref.invalidate(timesheetLogsProvider(widget.sheet.id)),
                builder: (list) {
                  if (list.isEmpty) return const Text('No time logged.');
                  final sorted = [...list]..sort((a, b) => a.date.compareTo(b.date));
                  return ListView(shrinkWrap: true, children: [
                    for (final l in sorted)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Text('${l.hours}h', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                        title: Text('${l.projectName.isEmpty ? 'Project' : l.projectName} · ${formatYmd(l.date)}'),
                        subtitle: Text(
                          [l.workLogTypeName, if (l.isBillable) 'Billable', if (l.comments.isNotEmpty) l.comments]
                              .where((e) => e.isNotEmpty)
                              .join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ]);
                },
              ),
            ),
            const SizedBox(height: 10),
            _busy
                ? const Center(child: CircularProgressIndicator())
                : _Buttons(onReject: () => _decide(false), onApprove: () => _decide(true)),
          ],
        ),
      ),
    );
  }
}

// ============================================================== comp-off

class CompOffApprovals extends ConsumerWidget {
  const CompOffApprovals({super.key});

  Future<void> _act(BuildContext context, WidgetRef ref, CompOffItem c, bool approve) async {
    String? reason = '';
    if (!approve) {
      reason = await askRemarks(context, title: 'Reject comp-off', confirm: 'Reject');
      if (reason == null) return;
    }
    try {
      final r = await ref.read(requestDataSourceProvider).decideCompOff(c.id, approve: approve, reason: reason);
      if (context.mounted) _report(context, r);
      ref.invalidate(compOffsToReviewProvider);
      ref.invalidate(approvalsInboxProvider);
    } catch (e) {
      if (context.mounted) _reportError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<List<CompOffItem>>(
      compact: true,
      value: ref.watch(compOffsToReviewProvider),
      onRetry: () => ref.invalidate(compOffsToReviewProvider),
      builder: (list) {
        if (list.isEmpty) return Text('Nothing pending.', style: TextStyle(color: Colors.grey.shade600));
        return Column(children: [
          for (final c in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SurfaceCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    UserAvatar(name: c.empName, radius: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(c.empName, style: const TextStyle(fontWeight: FontWeight.w700))),
                    Text(formatYmd(c.requestDate, withYear: true), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                  if ((c.reason ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(c.reason!, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                  ],
                  const SizedBox(height: 8),
                  _Buttons(onReject: () => _act(context, ref, c, false), onApprove: () => _act(context, ref, c, true)),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}

// ============================================================ late entry

class LateEntryApprovals extends ConsumerWidget {
  const LateEntryApprovals({super.key});

  Future<void> _resolve(BuildContext context, WidgetRef ref, LateEntryItem e) async {
    final remarks = await askRemarks(context, title: 'Resolve late entry', confirm: 'Resolve', required: true);
    if (remarks == null) return;
    try {
      final r = await ref.read(requestDataSourceProvider).resolveLateEntry(e.id, remarks);
      if (context.mounted) _report(context, r);
      ref.invalidate(lateEntriesProvider);
      ref.invalidate(approvalsInboxProvider);
    } catch (err) {
      if (context.mounted) _reportError(context, err);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<List<LateEntryItem>>(
      compact: true,
      value: ref.watch(lateEntriesProvider),
      onRetry: () => ref.invalidate(lateEntriesProvider),
      builder: (list) {
        if (list.isEmpty) return Text('Nothing pending.', style: TextStyle(color: Colors.grey.shade600));
        return Column(children: [
          for (final e in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SurfaceCard(
                child: Row(children: [
                  UserAvatar(name: e.empName, radius: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.empName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${formatYmd(e.date, withYear: true)} · ${e.lateByMinutes} min late${(e.shiftName ?? '').isNotEmpty ? ' · ${e.shiftName}' : ''}',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5)),
                    ]),
                  ),
                  TextButton(onPressed: () => _resolve(context, ref, e), child: const Text('Resolve')),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}

// ========================================================= HR leave (org)

/// Every pending leave request in the organisation, for HR / org admins.
class HrLeaveApprovalsScreen extends ConsumerWidget {
  const HrLeaveApprovalsScreen({super.key});

  Future<void> _act(BuildContext context, WidgetRef ref, LeaveRequest l, bool approve) async {
    String? reason = '';
    if (!approve) {
      reason = await askRemarks(context, title: 'Reject leave', confirm: 'Reject');
      if (reason == null) return;
    }
    try {
      final r = await ref.read(requestDataSourceProvider).decideLeave(l.id, approve: approve, reason: reason);
      if (context.mounted) _report(context, r);
      ref.invalidate(orgLeaveRequestsProvider);
      ref.invalidate(approvalsInboxProvider);
    } catch (e) {
      if (context.mounted) _reportError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('HR leave approvals')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(orgLeaveRequestsProvider);
          await ref.read(orgLeaveRequestsProvider.future);
        },
        child: AsyncValueView<List<LeaveRequest>>(
          value: ref.watch(orgLeaveRequestsProvider),
          onRetry: () => ref.invalidate(orgLeaveRequestsProvider),
          builder: (all) {
            final pending = all.where((l) => l.statusId == LeaveStatus.created).toList();
            if (pending.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 100),
                EmptyStateWidget(title: 'No pending leave', subtitle: 'Every request is decided.', icon: Icons.task_alt_outlined),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: pending.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final l = pending[i];
                return SurfaceCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      UserAvatar(name: l.employeeName ?? '', radius: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text((l.employeeName ?? '').trim(), style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('${l.leaveTypeName} · ${formatDateRange(l.fromDate, l.toDate)}',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                        ]),
                      ),
                      StatusChip(label: '${l.noOfDays} d', color: AppColors.primary),
                    ]),
                    if ((l.reason ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(l.reason!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
                    ],
                    const SizedBox(height: 8),
                    _Buttons(onReject: () => _act(context, ref, l, false), onApprove: () => _act(context, ref, l, true)),
                  ]),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ========================================================== resignations

/// All resignations. Manager stage first, then HR stage - one screen for both roles;
/// the server enforces who may act.
class ResignationApprovalsScreen extends ConsumerWidget {
  const ResignationApprovalsScreen({super.key});

  Future<void> _act(BuildContext context, WidgetRef ref, ResignationItem r, bool approve) async {
    final remarks = await askRemarks(
      context,
      title: approve ? 'Approve resignation' : 'Reject resignation',
      confirm: approve ? 'Approve' : 'Reject',
      required: !approve,
    );
    if (remarks == null) return;
    try {
      final res = await ref.read(requestDataSourceProvider).decideResignation(r, approve: approve, remarks: remarks);
      if (context.mounted) _report(context, res);
      ref.invalidate(allResignationsProvider);
    } catch (e) {
      if (context.mounted) _reportError(context, e);
    }
  }

  Color _color(int s) {
    switch (s) {
      case ResignationStatus.hrApproved:
        return AppColors.success;
      case ResignationStatus.managerRejected:
      case ResignationStatus.hrRejected:
        return AppColors.error;
      case ResignationStatus.withdrawn:
        return Colors.grey;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Resignations')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allResignationsProvider);
          await ref.read(allResignationsProvider.future);
        },
        child: AsyncValueView<List<ResignationItem>>(
          value: ref.watch(allResignationsProvider),
          onRetry: () => ref.invalidate(allResignationsProvider),
          builder: (all) {
            final list = all.where((r) => r.statusId != ResignationStatus.draft).toList();
            if (list.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 100),
                EmptyStateWidget(title: 'No resignations', icon: Icons.exit_to_app_rounded),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final r = list[i];
                final canAct = r.statusId == ResignationStatus.submitted || r.statusId == ResignationStatus.managerApproved;
                final hrStage = r.statusId == ResignationStatus.managerApproved;
                return SurfaceCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      UserAvatar(name: r.employeeName, radius: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.employeeName, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text([r.designation, r.department].where((e) => e.isNotEmpty).join(' · '),
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ]),
                      ),
                      StatusChip(label: ResignationStatus.label(r.statusId), color: _color(r.statusId)),
                    ]),
                    const SizedBox(height: 8),
                    Text('Last working day ${formatYmd(r.lastWorkingDate, withYear: true)}  ·  ${r.noticeDays} days notice',
                        style: const TextStyle(fontSize: 13)),
                    if ((r.reason ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(r.reason!, style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5)),
                      ),
                    if ((r.managerRemarks ?? '').isNotEmpty)
                      Text('Manager: ${r.managerRemarks}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    if ((r.hrRemarks ?? '').isNotEmpty)
                      Text('HR: ${r.hrRemarks}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    if (canAct) ...[
                      const SizedBox(height: 8),
                      _Buttons(
                        onReject: () => _act(context, ref, r, false),
                        onApprove: () => _act(context, ref, r, true),
                        approveLabel: hrStage ? 'HR approve' : 'Approve',
                        rejectLabel: hrStage ? 'HR reject' : 'Reject',
                      ),
                    ],
                  ]),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
