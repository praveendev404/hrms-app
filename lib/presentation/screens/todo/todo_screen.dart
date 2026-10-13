import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/dashboard_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/common/async_value_view.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/ui_helpers.dart';

const _reminders = <int, String>{
  0: 'No reminder',
  1: 'On the day',
  2: '1 day before',
  3: '3 days before',
  4: '1 week before',
};

/// Personal to-dos: add, complete, reopen, delete.
class TodoScreen extends ConsumerStatefulWidget {
  const TodoScreen({super.key});

  @override
  ConsumerState<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends ConsumerState<TodoScreen> {
  bool _showDone = false;

  void _refreshAll() {
    ref.invalidate(todoListProvider);
    ref.invalidate(todosWidgetProvider);
  }

  Future<void> _toggle(TodoItem t) async {
    try {
      final ds = ref.read(dashboardDataSourceProvider);
      if (t.isCompleted) {
        await ds.reopenTodo(t.id);
      } else {
        await ds.completeTodo(t.id);
      }
      _refreshAll();
    } catch (e) {
      _error(e);
    }
  }

  Future<void> _delete(TodoItem t) async {
    try {
      await ref.read(dashboardDataSourceProvider).deleteTodo(t.id);
      _refreshAll();
    } catch (e) {
      _error(e);
    }
  }

  void _error(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AsyncValueView.messageOf(e)), backgroundColor: Colors.red),
    );
  }

  Future<void> _openForm([TodoItem? t]) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TodoForm(todo: t),
    );
    if (ok == true) _refreshAll();
  }

  String _bucket(TodoItem t) {
    if (t.isCompleted) return DateFormat('EEE, d MMM').format(DateTime.tryParse(t.dueDate ?? '') ?? DateTime.now());
    if (t.isOverdue) return 'Overdue';
    final d = DateTime.tryParse(t.dueDate ?? '');
    if (d == null) return 'No date';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return DateFormat('EEE, d MMM').format(d);
  }

  Color _priorityColor(int? p) {
    switch (p) {
      case 3:
        return AppColors.error;
      case 2:
        return AppColors.warning;
      case 1:
        return AppColors.info;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(todoListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('My to-dos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('To do')),
                ButtonSegment(value: true, label: Text('Done')),
              ],
              selected: {_showDone},
              onSelectionChanged: (s) => setState(() => _showDone = s.first),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                _refreshAll();
                await ref.read(todoListProvider.future);
              },
              child: AsyncValueView<List<TodoItem>>(
                value: data,
                onRetry: _refreshAll,
                builder: (all) {
                  final items = all.where((t) => t.isCompleted == _showDone).toList()
                    ..sort((a, b) => _showDone
                        ? (b.dueDate ?? '').compareTo(a.dueDate ?? '')
                        : (a.dueDate ?? '').compareTo(b.dueDate ?? ''));
                  if (items.isEmpty) {
                    return ListView(children: [
                      const SizedBox(height: 100),
                      EmptyStateWidget(
                        title: _showDone ? 'Nothing completed yet' : 'You are all caught up',
                        subtitle: _showDone ? null : 'Tap New to add a to-do.',
                        icon: Icons.checklist_rounded,
                      ),
                    ]);
                  }

                  // Group by bucket, keeping order.
                  final groups = <String, List<TodoItem>>{};
                  for (final t in items) {
                    groups.putIfAbsent(_bucket(t), () => []).add(t);
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      for (final e in groups.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 6),
                          child: Text(e.key,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: e.key == 'Overdue' ? AppColors.error : AppColors.textSecondaryLight,
                              )),
                        ),
                        for (final t in e.value)
                          Dismissible(
                            key: ValueKey('todo-${t.id}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.only(right: 20),
                              alignment: Alignment.centerRight,
                              decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(16)),
                              child: const Icon(Icons.delete_outline, color: Colors.white),
                            ),
                            onDismissed: (_) => _delete(t),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: SurfaceCard(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                onTap: t.isCompleted ? null : () => _openForm(t),
                                child: Row(children: [
                                  Checkbox(
                                    value: t.isCompleted,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                    onChanged: (_) => _toggle(t),
                                  ),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(
                                        t.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          decoration: t.isCompleted ? TextDecoration.lineThrough : null,
                                          color: t.isCompleted ? Colors.grey : null,
                                        ),
                                      ),
                                      if ((t.description ?? '').isNotEmpty)
                                        Text(t.description!,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                      if ((t.dueTime ?? '').isNotEmpty)
                                        Text('at ${t.dueTime!.length >= 5 ? t.dueTime!.substring(0, 5) : t.dueTime}',
                                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                                    ]),
                                  ),
                                  if (t.priority != null)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Icon(Icons.flag_rounded, size: 18, color: _priorityColor(t.priority)),
                                    ),
                                ]),
                              ),
                            ),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodoForm extends ConsumerStatefulWidget {
  final TodoItem? todo;
  const _TodoForm({this.todo});

  @override
  ConsumerState<_TodoForm> createState() => _TodoFormState();
}

class _TodoFormState extends ConsumerState<_TodoForm> {
  late final _title = TextEditingController(text: widget.todo?.title ?? '');
  late final _desc = TextEditingController(text: widget.todo?.description ?? '');
  late DateTime _date = DateTime.tryParse(widget.todo?.dueDate ?? '') ?? DateTime.now();
  TimeOfDay? _time;
  late int? _priority = widget.todo?.priority;
  late int _reminder = widget.todo?.reminderType ?? 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final t = widget.todo?.dueTime;
    if (t != null && t.length >= 5) {
      _time = TimeOfDay(hour: int.tryParse(t.substring(0, 2)) ?? 0, minute: int.tryParse(t.substring(3, 5)) ?? 0);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a title.'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      String? time;
      if (_time != null) {
        time = '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}';
      }
      final r = await ref.read(dashboardDataSourceProvider).saveTodo(
            id: widget.todo?.id,
            title: _title.text.trim(),
            description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
            dueDate: DateFormat('yyyy-MM-dd').format(_date),
            dueTime: time,
            priority: _priority,
            reminderType: _reminder,
          );
      if (!mounted) return;
      if (r.success) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(r.message.isNotEmpty ? r.message : 'Could not save'), backgroundColor: Colors.red),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.todo == null ? 'New to-do' : 'Edit to-do',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            TextField(controller: _desc, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes (optional)')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (d != null) setState(() => _date = d);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Due date', suffixIcon: Icon(Icons.event_outlined, size: 18)),
                    child: Text(DateFormat('d MMM yyyy').format(_date)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: _time ?? TimeOfDay.now());
                    if (t != null) setState(() => _time = t);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Time',
                      suffixIcon: _time == null
                          ? const Icon(Icons.schedule, size: 18)
                          : IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => setState(() => _time = null),
                            ),
                    ),
                    child: Text(_time == null ? 'Optional' : _time!.format(context)),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              for (final p in const [(1, 'Low'), (2, 'Medium'), (3, 'High')])
                ChoiceChip(
                  label: Text(p.$2),
                  selected: _priority == p.$1,
                  onSelected: (sel) => setState(() => _priority = sel ? p.$1 : null),
                ),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _reminder,
              decoration: const InputDecoration(labelText: 'Reminder'),
              items: [for (final e in _reminders.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => setState(() => _reminder = v ?? 0),
            ),
            const SizedBox(height: 16),
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
