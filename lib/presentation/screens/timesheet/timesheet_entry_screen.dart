import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/dropdown_option_model.dart';
import '../../../data/models/work_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../widgets/common/async_value_view.dart';
import '../../widgets/common/ui_helpers.dart';
import 'my_timesheets_screen.dart';

final _ymd = DateFormat('yyyy-MM-dd');

/// Log hours for a week: pick a day, add work lines, submit the week for approval.
class TimesheetEntryScreen extends ConsumerStatefulWidget {
  const TimesheetEntryScreen({super.key});

  @override
  ConsumerState<TimesheetEntryScreen> createState() => _TimesheetEntryScreenState();
}

class _TimesheetEntryScreenState extends ConsumerState<TimesheetEntryScreen> {
  DateTime _weekStart = DateTime.now();
  bool _ready = false;
  late DateTime _selectedDay = DateTime.now();
  bool _busy = false;

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));
  String get _key => '${_ymd.format(_weekStart)}|${_ymd.format(_weekEnd)}';

  DateTime _startOfWeekFor(DateTime d, int weekStartDay) {
    // Dart: Monday=1..Sunday=7; the tenant setting uses 0=Sunday..6=Saturday.
    final dartWeekday = d.weekday % 7; // Sunday -> 0
    final offset = (dartWeekday - weekStartDay + 7) % 7;
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: offset));
  }

  void _toast(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? Colors.red : Colors.green),
    );
  }

  void _shiftWeek(int weeks) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * weeks));
      _selectedDay = _weekStart;
    });
  }

  Future<void> _setStatus(TimesheetSheet sheet, {required bool submit}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(submit ? 'Submit timesheet?' : 'Withdraw timesheet?'),
        content: Text(submit
            ? 'Your manager will review ${formatDateRange(sheet.fromDate, sheet.toDate)}. You can withdraw it until it is approved.'
            : 'It goes back to Draft so you can edit the hours.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Not now')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: Text(submit ? 'Submit' : 'Withdraw')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final r = await ref.read(extrasDataSourceProvider).setTimesheetStatus(
            sheet.id,
            submit ? TimesheetStatus.submitted : TimesheetStatus.draft,
            submit ? 'Submitted for approval' : 'Withdrawn',
          );
      _toast(r.message.isNotEmpty ? r.message : (r.success ? 'Done' : 'Action failed'), error: !r.success);
      ref.invalidate(timesheetWeekProvider(_key));
      ref.invalidate(myTimesheetsProvider);
    } catch (e) {
      _toast(AsyncValueView.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Copies yesterday's (or the last worked day's) entries onto the selected day.
  Future<void> _copyDay(TimesheetSheet sheet) async {
    final target = _ymd.format(_selectedDay);
    try {
      final p = await ref.read(extrasDataSourceProvider).getCopyPreview(sheet.id, target);
      if (!mounted) return;
      if (!p.ok || p.logs.isEmpty) {
        _toast(p.message.isNotEmpty ? p.message : 'There is nothing to copy onto this day.', error: true);
        return;
      }
      final go = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text('Copy from ${formatYmd(p.sourceDate)}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${p.logs.length} entr${p.logs.length == 1 ? 'y' : 'ies'} · ${p.hours} h will be added to ${formatYmd(target)}.'),
              const SizedBox(height: 8),
              for (final l in p.logs.take(6))
                Text('• ${l.hours}h  ${l.projectName.isEmpty ? 'Project' : l.projectName}', style: const TextStyle(fontSize: 13)),
              if (p.logs.length > 6) Text('…and ${p.logs.length - 6} more', style: const TextStyle(fontSize: 13)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(d, true), child: const Text('Copy')),
          ],
        ),
      );
      if (go != true) return;
      await _runCopy(sheet, mode: 'day', sourceDate: p.sourceDate, targetDate: target);
    } catch (e) {
      if (mounted) _toast(AsyncValueView.messageOf(e), error: true);
    }
  }

  Future<void> _copyWeek(TimesheetSheet sheet) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Copy last week?'),
        content: const Text('Every entry from the previous week is duplicated onto the same weekday here. You can edit the copies afterwards.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(d, true), child: const Text('Copy week')),
        ],
      ),
    );
    if (go == true) await _runCopy(sheet, mode: 'week');
  }

  Future<void> _runCopy(TimesheetSheet sheet, {required String mode, String? sourceDate, String? targetDate}) async {
    setState(() => _busy = true);
    try {
      final r = await ref
          .read(extrasDataSourceProvider)
          .copyWorkLogs(sheet.id, mode: mode, sourceDate: sourceDate, targetDate: targetDate);
      _toast(r.message.isNotEmpty ? r.message : (r.success ? 'Copied' : 'Nothing was copied'), error: !r.success);
      ref.invalidate(workLogsProvider(sheet.id));
      ref.invalidate(myTimesheetsProvider);
    } catch (e) {
      _toast(AsyncValueView.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openForm(TimesheetSheet sheet, {WorkLog? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _WorkLogForm(
        sheet: sheet,
        day: _selectedDay,
        existing: existing,
      ),
    );
    if (saved == true) {
      ref.invalidate(workLogsProvider(sheet.id));
      ref.invalidate(myTimesheetsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Wait for the tenant's week-start setting once, then snap to the current week.
    final weekStartDay = ref.watch(weekStartDayProvider);
    if (!_ready && weekStartDay.hasValue) {
      _weekStart = _startOfWeekFor(DateTime.now(), weekStartDay.value!);
      _selectedDay = DateTime.now().isBefore(_weekEnd.add(const Duration(days: 1))) ? DateTime.now() : _weekStart;
      _ready = true;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Timesheet'),
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyTimesheetsScreen())),
          ),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : AsyncValueView<TimesheetSheet>(
              value: ref.watch(timesheetWeekProvider(_key)),
              onRetry: () => ref.invalidate(timesheetWeekProvider(_key)),
              builder: (sheet) => _body(sheet),
            ),
    );
  }

  Widget _body(TimesheetSheet sheet) {
    final logs = ref.watch(workLogsProvider(sheet.id));
    final all = logs.valueOrNull ?? const <WorkLog>[];
    final total = all.fold<int>(0, (a, l) => a + l.hours);
    final dayKey = _ymd.format(_selectedDay);
    final dayLogs = all.where((l) => l.date == dayKey).toList();

    Color statusColor() {
      switch (sheet.statusId) {
        case TimesheetStatus.approved:
          return AppColors.success;
        case TimesheetStatus.rejected:
          return AppColors.error;
        case TimesheetStatus.submitted:
          return AppColors.info;
        default:
          return AppColors.warning;
      }
    }

    return Column(
      children: [
        // Week switcher
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shiftWeek(-1)),
                  Expanded(
                    child: Column(children: [
                      Text('${DateFormat('d MMM').format(_weekStart)} – ${DateFormat('d MMM yyyy').format(_weekEnd)}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 4),
                      StatusChip(
                          label: sheet.statusName.isEmpty ? 'Draft' : sheet.statusName, color: statusColor()),
                    ]),
                  ),
                  IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _shiftWeek(1)),
                ],
              ),
              // Day strip with hours per day
              SizedBox(
                height: 66,
                child: Row(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(child: _dayTile(_weekStart.add(Duration(days: i)), all)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(workLogsProvider(sheet.id));
              await ref.read(workLogsProvider(sheet.id).future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                SurfaceCard(
                  child: Row(children: [
                    const IconBadge(icon: Icons.timer_outlined, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('$total h this week', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        Text('${all.where((l) => l.isBillable).fold<int>(0, (a, l) => a + l.hours)} h billable',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                SectionHeader(DateFormat('EEEE, d MMM').format(_selectedDay),
                    actionLabel: sheet.isEditable ? 'Add' : null, onAction: () => _openForm(sheet)),
                if (sheet.isEditable)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Wrap(spacing: 8, children: [
                      ActionChip(
                        avatar: const Icon(Icons.content_copy_rounded, size: 16),
                        label: const Text('Copy previous day'),
                        onPressed: _busy ? null : () => _copyDay(sheet),
                      ),
                      if (all.isEmpty)
                        ActionChip(
                          avatar: const Icon(Icons.date_range_rounded, size: 16),
                          label: const Text('Copy last week'),
                          onPressed: _busy ? null : () => _copyWeek(sheet),
                        ),
                    ]),
                  ),
                const SizedBox(height: 4),
                AsyncValueView<List<WorkLog>>(
                  compact: true,
                  value: logs,
                  onRetry: () => ref.invalidate(workLogsProvider(sheet.id)),
                  builder: (_) {
                    if (dayLogs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(sheet.isEditable ? 'No time logged. Tap Add to log hours.' : 'No time logged for this day.',
                              style: TextStyle(color: Colors.grey.shade600)),
                        ),
                      );
                    }
                    return Column(children: [
                      for (final l in dayLogs)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SurfaceCard(
                            onTap: sheet.isEditable ? () => _openForm(sheet, existing: l) : null,
                            child: Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                    color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(12)),
                                child: Text('${l.hours}h',
                                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(l.projectName.isEmpty ? 'Project' : l.projectName,
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(
                                    [
                                      l.workLogTypeName,
                                      if ((l.taskNumber ?? '').isNotEmpty) l.taskNumber!,
                                      if (l.isBillable) 'Billable',
                                    ].where((e) => e.isNotEmpty).join('  ·  '),
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                  if (l.comments.isNotEmpty)
                                    Text(l.comments, maxLines: 2, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12.5)),
                                ]),
                              ),
                              if (sheet.isEditable) const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                            ]),
                          ),
                        ),
                    ]);
                  },
                ),
                const SizedBox(height: 16),
                if (sheet.canSubmit)
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: (_busy || total == 0) ? null : () => _setStatus(sheet, submit: true),
                      icon: const Icon(Icons.send_rounded),
                      label: Text(total == 0 ? 'Log time to submit' : 'Submit week for approval'),
                    ),
                  ),
                if (sheet.canWithdraw)
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _setStatus(sheet, submit: false),
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text('Withdraw submission'),
                    ),
                  ),
                if (sheet.statusId == TimesheetStatus.approved)
                  Center(
                    child: Text('Approved — hours are locked.', style: TextStyle(color: Colors.grey.shade600)),
                  ),
                if (sheet.statusId == TimesheetStatus.rejected)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('Rejected — fix the hours and submit again.',
                        style: TextStyle(color: Colors.red.shade400)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dayTile(DateTime d, List<WorkLog> all) {
    final key = _ymd.format(d);
    final hours = all.where((l) => l.date == key).fold<int>(0, (a, l) => a + l.hours);
    final selected = _ymd.format(_selectedDay) == key;
    final weekend = d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _selectedDay = d),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(DateFormat('E').format(d).substring(0, 1),
                style: TextStyle(
                    fontSize: 11, color: selected ? Colors.white70 : (weekend ? Colors.grey : Colors.grey.shade700))),
            const SizedBox(height: 2),
            Text('${d.day}',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: selected ? Colors.white : Colors.black87)),
            const SizedBox(height: 2),
            Text(hours > 0 ? '${hours}h' : '·',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : (hours > 0 ? AppColors.primary : Colors.grey))),
          ],
        ),
      ),
    );
  }
}

class _WorkLogForm extends ConsumerStatefulWidget {
  final TimesheetSheet sheet;
  final DateTime day;
  final WorkLog? existing;
  const _WorkLogForm({required this.sheet, required this.day, this.existing});

  @override
  ConsumerState<_WorkLogForm> createState() => _WorkLogFormState();
}

class _WorkLogFormState extends ConsumerState<_WorkLogForm> {
  late int? _projectId = widget.existing?.projectId;
  late int? _typeId = widget.existing?.workLogTypeId;
  late int _hours = widget.existing?.hours ?? 8;
  late bool _billable = widget.existing?.isBillable ?? false;
  late final _task = TextEditingController(text: widget.existing?.taskNumber ?? '');
  late final _comments = TextEditingController(text: widget.existing?.comments ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _task.dispose();
    _comments.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final empId = ref.read(userProfileProvider).profile?.employeeId;
    if (empId == null) return _toast('Your account is not linked to an employee record.');
    if (_projectId == null || _typeId == null) return _toast('Choose a project and a work type.');
    if (_comments.text.trim().isEmpty) return _toast('Add a short description of the work.');

    setState(() => _busy = true);
    try {
      final r = await ref.read(extrasDataSourceProvider).saveWorkLog(
            timesheetId: widget.sheet.id,
            employeeId: empId,
            weekFrom: widget.sheet.fromDate,
            weekTo: widget.sheet.toDate,
            log: WorkLog(
              id: widget.existing?.id,
              projectId: _projectId!,
              workLogTypeId: _typeId!,
              date: _ymd.format(widget.day),
              hours: _hours,
              taskNumber: _task.text.trim().isEmpty ? null : _task.text.trim(),
              comments: _comments.text.trim(),
              isBillable: _billable,
            ),
          );
      if (!mounted) return;
      _toast(r.message.isNotEmpty ? r.message : (r.success ? 'Saved' : 'Could not save'), error: !r.success);
      if (r.success) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _toast(AsyncValueView.messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String text, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? Colors.red : Colors.green),
    );
  }

  Widget _dropdown(String label, List<DropdownOptionModel> options, int? value, ValueChanged<int?> onChanged) {
    return DropdownButtonFormField<int>(
      value: options.any((o) => o.value == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [for (final o in options) DropdownMenuItem(value: o.value, child: Text(o.label))],
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectOptionsProvider).valueOrNull ?? <DropdownOptionModel>[];
    final types = ref.watch(workLogTypeOptionsProvider).valueOrNull ?? <DropdownOptionModel>[];

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existing == null ? 'Log time' : 'Edit entry',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(DateFormat('EEEE, d MMM yyyy').format(widget.day), style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 14),
            _dropdown('Project', projects, _projectId, (v) => setState(() => _projectId = v)),
            const SizedBox(height: 12),
            _dropdown('Work type', types, _typeId, (v) => setState(() => _typeId = v)),
            const SizedBox(height: 14),
            Row(children: [
              const Text('Hours', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: _hours > 1 ? () => setState(() => _hours--) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 56,
                child: Text('$_hours', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              IconButton.filledTonal(
                onPressed: _hours < 24 ? () => setState(() => _hours++) : null,
                icon: const Icon(Icons.add),
              ),
            ]),
            const SizedBox(height: 8),
            TextField(controller: _task, decoration: const InputDecoration(labelText: 'Task / ticket no. (optional)')),
            const SizedBox(height: 12),
            TextField(
              controller: _comments,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'What did you work on?'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Billable'),
              value: _billable,
              onChanged: (v) => setState(() => _billable = v),
            ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
