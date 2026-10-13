import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/dropdown_option_model.dart';
import '../../../data/models/request_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../widgets/common/async_value_view.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/ui_helpers.dart';

Color _statusColor(int id, {required int approved, required int rejected}) {
  if (id == approved) return AppColors.success;
  if (id == rejected) return AppColors.error;
  if (id == WfhStatus.cancelled) return Colors.grey;
  return AppColors.warning;
}

void _toast(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), backgroundColor: error ? Colors.red : Colors.green),
  );
}

/// Attendance regularization + work-from-home requests (mine).
class RequestsScreen extends ConsumerWidget {
  /// 0 = regularization, 1 = work from home.
  final int initialTab;
  const RequestsScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('My requests'),
          bottom: const TabBar(tabs: [Tab(text: 'Regularization'), Tab(text: 'Work from home')]),
        ),
        body: const TabBarView(children: [_RegularizationTab(), _WfhTab()]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _RegularizationTab extends ConsumerWidget {
  const _RegularizationTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final empId = ref.watch(userProfileProvider).profile?.employeeId;
    final data = ref.watch(regularizationsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'reg-fab',
        onPressed: () async {
          final ok = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const RegularizeForm(),
          );
          if (ok == true) ref.invalidate(regularizationsProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(regularizationsProvider);
          await ref.read(regularizationsProvider.future);
        },
        child: AsyncValueView<List<RegularizeItem>>(
          value: data,
          onRetry: () => ref.invalidate(regularizationsProvider),
          builder: (all) {
            final mine = all.where((r) => r.empId == empId).toList();
            if (mine.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 100),
                EmptyStateWidget(
                  title: 'No regularization requests',
                  subtitle: 'Missed a punch? Tap New to request a correction.',
                  icon: Icons.edit_calendar_outlined,
                ),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: mine.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final r = mine[i];
                return SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(formatYmd(r.date, withYear: true), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        StatusChip(
                          label: r.statusName,
                          color: _statusColor(r.statusId, approved: RegularizeStatus.approved, rejected: RegularizeStatus.rejected),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(r.typeName, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                      if (r.inTime != null || r.outTime != null)
                        Text('In ${r.inTime ?? '--'}  ·  Out ${r.outTime ?? '--'}',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      if ((r.notes ?? '').isNotEmpty)
                        Text(r.notes!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
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

class RegularizeForm extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  const RegularizeForm({super.key, this.initialDate});

  @override
  ConsumerState<RegularizeForm> createState() => _RegularizeFormState();
}

class _RegularizeFormState extends ConsumerState<RegularizeForm> {
  final _notes = TextEditingController();
  int? _typeId;
  late DateTime? _date = widget.initialDate;
  TimeOfDay? _in;
  TimeOfDay? _out;
  bool _busy = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  String _t(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _submit() async {
    final empId = ref.read(userProfileProvider).profile?.employeeId;
    if (empId == null) return _toast(context, 'Your account is not linked to an employee record.', error: true);
    if (_typeId == null || _date == null || _notes.text.trim().isEmpty) {
      return _toast(context, 'Select a type, a date and add notes.', error: true);
    }
    setState(() => _busy = true);
    try {
      final r = await ref.read(requestDataSourceProvider).addRegularization(
            empId: empId,
            typeId: _typeId!,
            date: DateFormat('yyyy-MM-dd').format(_date!),
            notes: _notes.text.trim(),
            inTime: _in == null ? null : _t(_in!),
            outTime: _out == null ? null : _t(_out!),
          );
      if (!mounted) return;
      _toast(context, r.message.isNotEmpty ? r.message : (r.success ? 'Request submitted' : 'Failed'), error: !r.success);
      if (r.success) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _toast(context, AsyncValueView.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = ref.watch(regularizeTypeOptionsProvider).valueOrNull ?? <DropdownOptionModel>[];
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Regularize attendance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [for (final t in types) DropdownMenuItem(value: t.value, child: Text(t.label))],
              onChanged: (v) => setState(() => _typeId = v),
            ),
            const SizedBox(height: 12),
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
                decoration: const InputDecoration(labelText: 'Date', suffixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
                child: Text(_date == null ? 'Select' : DateFormat('d MMM yyyy').format(_date!)),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _timeField('In time', _in, (t) => setState(() => _in = t))),
              const SizedBox(width: 12),
              Expanded(child: _timeField('Out time', _out, (t) => setState(() => _out = t))),
            ]),
            const SizedBox(height: 12),
            TextField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeField(String label, TimeOfDay? value, ValueChanged<TimeOfDay> onPicked) {
    return InkWell(
      onTap: () async {
        final t = await showTimePicker(context: context, initialTime: value ?? TimeOfDay.now());
        if (t != null) onPicked(t);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.schedule, size: 18)),
        child: Text(value == null ? 'Optional' : value.format(context)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _WfhTab extends ConsumerWidget {
  const _WfhTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(myWfhProvider);

    Future<void> cancel(WfhItem w) async {
      try {
        final r = await ref.read(requestDataSourceProvider).setWfhStatus(w.id, WfhStatus.cancelled);
        if (context.mounted) {
          _toast(context, r.message.isNotEmpty ? r.message : (r.success ? 'Cancelled' : 'Failed'), error: !r.success);
        }
        ref.invalidate(myWfhProvider);
      } catch (e) {
        if (context.mounted) _toast(context, AsyncValueView.messageOf(e), error: true);
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'wfh-fab',
        onPressed: () async {
          final ok = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const _WfhForm(),
          );
          if (ok == true) ref.invalidate(myWfhProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myWfhProvider);
          await ref.read(myWfhProvider.future);
        },
        child: AsyncValueView<List<WfhItem>>(
          value: data,
          onRetry: () => ref.invalidate(myWfhProvider),
          builder: (list) {
            if (list.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 100),
                EmptyStateWidget(
                  title: 'No work-from-home requests',
                  icon: Icons.home_work_outlined,
                ),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final w = list[i];
                return SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(formatDateRange(w.fromDate, w.toDate), style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        StatusChip(
                          label: w.statusName,
                          color: _statusColor(w.statusId, approved: WfhStatus.approved, rejected: WfhStatus.rejected),
                        ),
                      ]),
                      if ((w.reason ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(w.reason!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      ],
                      if (w.isPending)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(onPressed: () => cancel(w), child: const Text('Cancel request')),
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

class _WfhForm extends ConsumerStatefulWidget {
  const _WfhForm();

  @override
  ConsumerState<_WfhForm> createState() => _WfhFormState();
}

class _WfhFormState extends ConsumerState<_WfhForm> {
  final _reason = TextEditingController();
  DateTime? _from;
  DateTime? _to;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pick(bool isFrom) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? _from ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: DateTime(now.year + 1),
    );
    if (d == null) return;
    setState(() {
      if (isFrom) {
        _from = d;
        if (_to == null || _to!.isBefore(d)) _to = d;
      } else {
        _to = d;
        _from ??= d;
      }
    });
  }

  Future<void> _submit() async {
    if (_from == null || _to == null) return _toast(context, 'Select the dates.', error: true);
    final f = DateFormat('yyyy-MM-dd');
    setState(() => _busy = true);
    try {
      final r = await ref.read(requestDataSourceProvider).addWfh(
            fromDate: f.format(_from!),
            toDate: f.format(_to!),
            reason: _reason.text.trim(),
          );
      if (!mounted) return;
      _toast(context, r.message.isNotEmpty ? r.message : (r.success ? 'Request submitted' : 'Failed'), error: !r.success);
      if (r.success) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _toast(context, AsyncValueView.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _date(String label, DateTime? v, bool isFrom) => InkWell(
        onTap: () => _pick(isFrom),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18)),
          child: Text(v == null ? 'Select' : DateFormat('d MMM yyyy').format(v)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Request work from home', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _date('From', _from, true)),
              const SizedBox(width: 12),
              Expanded(child: _date('To', _to, false)),
            ]),
            const SizedBox(height: 12),
            TextField(controller: _reason, maxLines: 3, decoration: const InputDecoration(labelText: 'Reason')),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
