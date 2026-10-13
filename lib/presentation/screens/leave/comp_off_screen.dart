import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/work_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../widgets/common/async_value_view.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/ui_helpers.dart';

/// Compensatory off: request a day off for extra days worked, and track the requests.
class CompOffScreen extends ConsumerWidget {
  const CompOffScreen({super.key});

  Color _color(int s) {
    switch (s) {
      case 2:
        return AppColors.success;
      case 4:
        return AppColors.error;
      case 3:
        return Colors.grey;
      default:
        return AppColors.warning;
    }
  }

  Future<void> _request(BuildContext context, WidgetRef ref, int empId) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CompOffForm(),
    );
    if (ok == true) ref.invalidate(myCompOffProvider(empId));
  }

  Future<void> _withdraw(BuildContext context, WidgetRef ref, int empId, CompOffItem c) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Withdraw request?'),
        content: Text('Comp-off for ${formatYmd(c.requestDate, withYear: true)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Withdraw')),
        ],
      ),
    );
    if (go != true) return;
    try {
      final r = await ref.read(extrasDataSourceProvider).cancelCompOff(c.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(r.message.isNotEmpty ? r.message : (r.success ? 'Withdrawn' : 'Failed')),
          backgroundColor: r.success ? Colors.green : Colors.red,
        ));
      }
      ref.invalidate(myCompOffProvider(empId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AsyncValueView.messageOf(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empId = ref.watch(userProfileProvider).profile?.employeeId;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Comp-off')),
      floatingActionButton: empId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _request(context, ref, empId),
              icon: const Icon(Icons.add),
              label: const Text('Request'),
            ),
      body: empId == null
          ? const Center(child: Text('Your account is not linked to an employee record.'))
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(myCompOffProvider(empId));
                await ref.read(myCompOffProvider(empId).future);
              },
              child: AsyncValueView<List<CompOffItem>>(
                value: ref.watch(myCompOffProvider(empId)),
                onRetry: () => ref.invalidate(myCompOffProvider(empId)),
                builder: (list) {
                  if (list.isEmpty) {
                    return ListView(children: const [
                      SizedBox(height: 100),
                      EmptyStateWidget(
                        title: 'No comp-off requests',
                        subtitle: 'Worked on a weekend or holiday? Tap Request.',
                        icon: Icons.more_time_outlined,
                      ),
                    ]);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final c = list[i];
                      return SurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const IconBadge(icon: Icons.more_time_rounded, color: AppColors.tertiary, size: 40),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(formatYmd(c.requestDate, withYear: true),
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              ),
                              StatusChip(label: c.statusName, color: _color(c.statusId)),
                            ]),
                            if ((c.reason ?? '').isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(c.reason!, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                            ],
                            if (c.canWithdraw)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => _withdraw(context, ref, empId, c),
                                  child: const Text('Withdraw'),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
    );
  }
}

class _CompOffForm extends ConsumerStatefulWidget {
  const _CompOffForm();

  @override
  ConsumerState<_CompOffForm> createState() => _CompOffFormState();
}

class _CompOffFormState extends ConsumerState<_CompOffForm> {
  final _reason = TextEditingController();
  DateTime? _date;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _toast(String text, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? Colors.red : Colors.green),
    );
  }

  Future<void> _submit() async {
    if (_date == null) return _toast('Choose the date you worked.');
    if (_reason.text.trim().isEmpty) return _toast('Add a reason.');
    setState(() => _busy = true);
    try {
      final r = await ref.read(extrasDataSourceProvider).requestCompOff(
            date: DateFormat('yyyy-MM-dd').format(_date!),
            reason: _reason.text.trim(),
          );
      if (!mounted) return;
      _toast(r.message.isNotEmpty ? r.message : (r.success ? 'Request sent' : 'Failed'), error: !r.success);
      if (r.success) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _toast(AsyncValueView.messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
            const Text('Request comp-off', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Pick the extra day you worked.', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 14),
            InkWell(
              onTap: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date ?? now,
                  firstDate: DateTime(now.year - 1),
                  lastDate: now,
                );
                if (d != null) setState(() => _date = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'Date worked', suffixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
                child: Text(_date == null ? 'Select' : DateFormat('d MMM yyyy').format(_date!)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(controller: _reason, maxLines: 3, decoration: const InputDecoration(labelText: 'Reason')),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Send request'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
