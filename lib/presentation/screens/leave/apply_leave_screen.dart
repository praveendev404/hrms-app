import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/dropdown_option_model.dart';
import '../../../data/models/leave_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../widgets/common/async_value_view.dart';
import '../../widgets/common/custom_text_field.dart';

/// Apply for leave. Leave/day types come from the API and the number of days
/// is computed by the server (holidays, week-offs and half days live there).
class ApplyLeaveScreen extends ConsumerStatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  ConsumerState<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends ConsumerState<ApplyLeaveScreen> {
  final _reason = TextEditingController();
  final _fmt = DateFormat('yyyy-MM-dd');

  int? _leaveTypeId;
  int? _fromDayTypeId;
  int? _toDayTypeId;
  DateTime? _from;
  DateTime? _to;

  LeaveDayCount? _dayCount;
  bool _counting = false;
  bool _submitting = false;
  String? _countError;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (ref.read(userProfileProvider).profile == null) {
      Future.microtask(() => ref.read(userProfileProvider.notifier).fetchUserProfile());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _reason.dispose();
    super.dispose();
  }

  int? get _employeeId => ref.read(userProfileProvider).profile?.employeeId;

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = (isFrom ? _from : _to) ?? _from ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to == null || _to!.isBefore(picked)) _to = picked;
      } else {
        _to = picked;
        _from ??= picked;
      }
    });
    _recount();
  }

  /// Debounced server-side day count; the submit path refuses a mismatching figure.
  void _recount() {
    _debounce?.cancel();
    final empId = _employeeId;
    if (_from == null || _to == null || _fromDayTypeId == null || _toDayTypeId == null || empId == null) {
      setState(() => _dayCount = null);
      return;
    }
    setState(() {
      _counting = true;
      _countError = null;
    });
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final r = await ref.read(leaveDataSourceProvider).getDayCount(
              employeeId: empId,
              fromDate: _fmt.format(_from!),
              toDate: _fmt.format(_to!),
              fromDayTypeId: _fromDayTypeId!,
              toDayTypeId: _toDayTypeId!,
            );
        if (mounted) {
          setState(() {
            _dayCount = r;
            _counting = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _dayCount = null;
            _counting = false;
            _countError = AsyncValueView.messageOf(e);
          });
        }
      }
    });
  }

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? Colors.red : Colors.green),
    );
  }

  Future<void> _submit() async {
    final empId = _employeeId;
    if (empId == null) {
      _snack('Your account is not linked to an employee record.', error: true);
      return;
    }
    if (_leaveTypeId == null || _from == null || _to == null || _fromDayTypeId == null || _toDayTypeId == null) {
      _snack('Please fill in all required fields.', error: true);
      return;
    }
    if (_reason.text.trim().isEmpty) {
      _snack('Please enter a reason.', error: true);
      return;
    }
    final count = _dayCount;
    if (_counting || count == null || !count.isSubmittable) {
      _snack(count?.problemMessage ?? 'The number of days is still being worked out.', error: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      final r = await ref.read(leaveDataSourceProvider).apply(
            employeeId: empId,
            leaveTypeId: _leaveTypeId!,
            fromDate: _fmt.format(_from!),
            toDate: _fmt.format(_to!),
            fromDayTypeId: _fromDayTypeId!,
            toDayTypeId: _toDayTypeId!,
            noOfDays: count.noOfDays,
            reason: _reason.text.trim(),
          );
      if (!mounted) return;
      if (r.success) {
        _snack(r.message.isNotEmpty ? r.message : 'Leave request submitted');
        Navigator.pop(context, true);
      } else {
        _snack(r.message.isNotEmpty ? r.message : 'Could not submit leave request', error: true);
      }
    } catch (e) {
      if (mounted) _snack(AsyncValueView.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _dropdown({
    required String label,
    required List<DropdownOptionModel> options,
    required int? value,
    required ValueChanged<int?> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      value: options.any((o) => o.value == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final o in options) DropdownMenuItem(value: o.value, child: Text(o.label)),
      ],
      onChanged: onChanged,
    );
  }

  /// "Balance: 4 of 12 left" for the chosen type, from /leave/myleaveinfo.
  Widget _balanceHint() {
    if (_leaveTypeId == null) return const SizedBox.shrink();
    final list = ref.watch(leaveBalancesProvider).valueOrNull ?? const [];
    final match = list.where((b) => b.leaveTypeId == _leaveTypeId);
    if (match.isEmpty) return const SizedBox.shrink();
    final b = match.first;
    String n(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 1);
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Text(
        'Balance: ${n(b.remaining)} of ${n(b.total)} left',
        style: TextStyle(fontSize: 12, color: b.remaining <= 0 ? Colors.red : Colors.grey.shade700),
      ),
    );
  }

  Widget _dateTile(String label, DateTime? value, bool isFrom) {
    return InkWell(
      onTap: () => _pickDate(isFrom: isFrom),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18)),
        child: Text(value == null ? 'Select' : DateFormat('d MMM yyyy').format(value)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leaveTypes = ref.watch(leaveTypeOptionsProvider);
    final dayTypes = ref.watch(dayTypeOptionsProvider);

    // Default both day types to the first option (Full Day) once they arrive.
    final dt = dayTypes.valueOrNull;
    if (dt != null && dt.isNotEmpty && _fromDayTypeId == null) {
      _fromDayTypeId = dt.first.value;
      _toDayTypeId = dt.first.value;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Apply for leave')),
      body: AsyncValueView<List<DropdownOptionModel>>(
        value: leaveTypes,
        onRetry: () => ref.invalidate(leaveTypeOptionsProvider),
        builder: (types) => AsyncValueView<List<DropdownOptionModel>>(
          value: dayTypes,
          onRetry: () => ref.invalidate(dayTypeOptionsProvider),
          builder: (days) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _dropdown(
                label: 'Leave type',
                options: types,
                value: _leaveTypeId,
                onChanged: (v) => setState(() => _leaveTypeId = v),
              ),
              _balanceHint(),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _dateTile('From', _from, true)),
                const SizedBox(width: 12),
                Expanded(child: _dateTile('To', _to, false)),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: _dropdown(
                    label: 'From day',
                    options: days,
                    value: _fromDayTypeId,
                    onChanged: (v) {
                      setState(() => _fromDayTypeId = v);
                      _recount();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dropdown(
                    label: 'To day',
                    options: days,
                    value: _toDayTypeId,
                    onChanged: (v) {
                      setState(() => _toDayTypeId = v);
                      _recount();
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              _DayCountBanner(counting: _counting, count: _dayCount, error: _countError),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _reason,
                labelText: 'Reason',
                maxLines: 3,
                minLines: 3,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Submit request'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayCountBanner extends StatelessWidget {
  final bool counting;
  final LeaveDayCount? count;
  final String? error;

  const _DayCountBanner({required this.counting, required this.count, required this.error});

  @override
  Widget build(BuildContext context) {
    String text;
    Color color;
    if (counting) {
      text = 'Calculating days…';
      color = Colors.grey;
    } else if (error != null) {
      text = error!;
      color = Colors.red;
    } else if (count == null) {
      text = 'Pick dates to see the number of days.';
      color = Colors.grey;
    } else if (!count!.isSubmittable) {
      text = count!.problemMessage ?? 'Choose valid dates.';
      color = Colors.red;
    } else {
      text = '${count!.noOfDays} working day(s) will be deducted';
      color = Colors.green;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(Icons.info_outline, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 13))),
      ]),
    );
  }
}
