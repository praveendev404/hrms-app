import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/work_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../widgets/common/async_value_view.dart';
import '../../widgets/common/ui_helpers.dart';

final _ymd = DateFormat('yyyy-MM-dd');

/// My resignation: start a request, submit it, track approvals, or withdraw.
class ResignationScreen extends ConsumerWidget {
  const ResignationScreen({super.key});

  Color _color(int s) {
    switch (s) {
      case ResignationStatus.hrApproved:
        return AppColors.success;
      case ResignationStatus.managerRejected:
      case ResignationStatus.hrRejected:
        return AppColors.error;
      case ResignationStatus.withdrawn:
        return Colors.grey;
      case ResignationStatus.draft:
        return AppColors.warning;
      default:
        return AppColors.info;
    }
  }

  void _toast(BuildContext context, String text, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? Colors.red : Colors.green),
    );
  }

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    int empId, {
    required String title,
    required String body,
    required String confirm,
    required Future<dynamic> Function() run,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Not now')),
          ElevatedButton(onPressed: () => Navigator.pop(d, true), child: Text(confirm)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final r = await run();
      if (context.mounted) {
        _toast(context, r.message.isNotEmpty ? r.message : (r.success ? 'Done' : 'Action failed'), error: !r.success);
      }
      ref.invalidate(myResignationProvider(empId));
    } catch (e) {
      if (context.mounted) _toast(context, AsyncValueView.messageOf(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empId = ref.watch(userProfileProvider).profile?.employeeId;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Resignation')),
      body: empId == null
          ? const Center(child: Text('Your account is not linked to an employee record.'))
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(myResignationProvider(empId));
                await ref.read(myResignationProvider(empId).future);
              },
              child: AsyncValueView<ResignationItem?>(
                value: ref.watch(myResignationProvider(empId)),
                onRetry: () => ref.invalidate(myResignationProvider(empId)),
                builder: (r) {
                  // No request, or a closed-out one: offer to start a new one.
                  if (r == null || r.isFinished) {
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (r != null) _StatusCard(item: r, color: _color(r.statusId)),
                        if (r != null) const SizedBox(height: 16),
                        SurfaceCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const IconBadge(icon: Icons.exit_to_app_rounded, color: AppColors.secondary),
                              const SizedBox(height: 12),
                              const Text('Thinking of leaving?',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text('Start a resignation request. Your manager and HR will review it, and you can withdraw it any time before it is approved.',
                                  style: TextStyle(color: Colors.grey.shade700)),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final ok = await showModalBottomSheet<bool>(
                                      context: context,
                                      isScrollControlled: true,
                                      builder: (_) => const _ResignationForm(),
                                    );
                                    if (ok == true) ref.invalidate(myResignationProvider(empId));
                                  },
                                  child: const Text('Start resignation'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _StatusCard(item: r, color: _color(r.statusId)),
                      const SizedBox(height: 16),
                      if (r.canEdit)
                        OutlinedButton.icon(
                          onPressed: () async {
                            final ok = await showModalBottomSheet<bool>(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => _ResignationForm(existing: r),
                            );
                            if (ok == true) ref.invalidate(myResignationProvider(empId));
                          },
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit draft'),
                        ),
                      if (r.canSubmit) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () => _act(
                              context,
                              ref,
                              empId,
                              title: 'Submit resignation?',
                              body: 'Your manager will be notified and the request moves to approval.',
                              confirm: 'Submit',
                              run: () => ref.read(extrasDataSourceProvider).submitResignation(r.id!),
                            ),
                            icon: const Icon(Icons.send_rounded),
                            label: const Text('Submit for approval'),
                          ),
                        ),
                      ],
                      if (r.canWithdraw) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: () => _act(
                              context,
                              ref,
                              empId,
                              title: 'Withdraw resignation?',
                              body: 'The request is cancelled and you stay on.',
                              confirm: 'Withdraw',
                              run: () => ref.read(extrasDataSourceProvider).withdrawResignation(r.id!),
                            ),
                            icon: const Icon(Icons.undo_rounded),
                            label: const Text('Withdraw request'),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final ResignationItem item;
  final Color color;
  const _StatusCard({required this.item, required this.color});

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(child: Text('Your resignation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            StatusChip(label: ResignationStatus.label(item.statusId), color: color),
          ]),
          const Divider(height: 24),
          _row('Resignation date', formatYmd(item.resignationDate, withYear: true)),
          _row('Last working day', formatYmd(item.lastWorkingDate, withYear: true)),
          _row('Notice period', '${item.noticeDays} days'),
          if ((item.reason ?? '').isNotEmpty) _row('Reason', item.reason!),
          if ((item.managerRemarks ?? '').isNotEmpty) _row('Manager remarks', item.managerRemarks!),
          if ((item.hrRemarks ?? '').isNotEmpty) _row('HR remarks', item.hrRemarks!),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 130, child: Text(k, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}

class _ResignationForm extends ConsumerStatefulWidget {
  final ResignationItem? existing;
  const _ResignationForm({this.existing});

  @override
  ConsumerState<_ResignationForm> createState() => _ResignationFormState();
}

class _ResignationFormState extends ConsumerState<_ResignationForm> {
  late DateTime _date = DateTime.tryParse(widget.existing?.resignationDate ?? '') ?? DateTime.now();
  late int _notice = widget.existing?.noticeDays ?? 30;
  late DateTime _lastDay = DateTime.tryParse(widget.existing?.lastWorkingDate ?? '') ?? DateTime.now().add(const Duration(days: 30));
  late final _reason = TextEditingController(text: widget.existing?.reason ?? '');
  late final _remarks = TextEditingController(text: widget.existing?.remarks ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    _remarks.dispose();
    super.dispose();
  }

  /// Keeps the last working day in step with the notice period unless it was picked by hand.
  void _syncLastDay() => _lastDay = _date.add(Duration(days: _notice));

  Future<void> _save() async {
    final empId = ref.read(userProfileProvider).profile?.employeeId;
    if (empId == null) return;
    if (_reason.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please give a reason for leaving.'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await ref.read(extrasDataSourceProvider).saveResignation(
            ResignationItem(
              id: widget.existing?.id,
              resignationDate: _ymd.format(_date),
              lastWorkingDate: _ymd.format(_lastDay),
              noticeDays: _notice,
              reason: _reason.text.trim(),
              remarks: _remarks.text.trim().isEmpty ? null : _remarks.text.trim(),
              statusId: widget.existing?.statusId ?? ResignationStatus.draft,
            ),
            empId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r.message.isNotEmpty ? r.message : (r.success ? 'Saved as draft' : 'Could not save')),
        backgroundColor: r.success ? Colors.green : Colors.red,
      ));
      if (r.success) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AsyncValueView.messageOf(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _dateField(String label, DateTime value, ValueChanged<DateTime> onPick, {DateTime? first}) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: first ?? DateTime.now().subtract(const Duration(days: 30)),
          lastDate: DateTime.now().add(const Duration(days: 730)),
        );
        if (d != null) setState(() => onPick(d));
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.event_outlined, size: 18)),
        child: Text(DateFormat('d MMM yyyy').format(value)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existing == null ? 'Start resignation' : 'Edit draft',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            _dateField('Resignation date', _date, (d) {
              _date = d;
              _syncLastDay();
            }),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Notice period', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: _notice > 0
                    ? () => setState(() {
                          _notice = (_notice - 15).clamp(0, 365);
                          _syncLastDay();
                        })
                    : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(width: 70, child: Text('$_notice days', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800))),
              IconButton.filledTonal(
                onPressed: () => setState(() {
                  _notice = (_notice + 15).clamp(0, 365);
                  _syncLastDay();
                }),
                icon: const Icon(Icons.add),
              ),
            ]),
            const SizedBox(height: 12),
            _dateField('Last working day', _lastDay, (d) => _lastDay = d, first: _date),
            const SizedBox(height: 12),
            TextField(controller: _reason, maxLines: 3, decoration: const InputDecoration(labelText: 'Reason for leaving')),
            const SizedBox(height: 12),
            TextField(controller: _remarks, maxLines: 2, decoration: const InputDecoration(labelText: 'Anything else? (optional)')),
            const SizedBox(height: 6),
            Text('This saves a draft. You submit it for approval in the next step.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save draft'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
