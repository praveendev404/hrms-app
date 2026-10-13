import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/work_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/common/async_value_view.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/ui_helpers.dart';

/// Onboarding tasks assigned to me (for example IT setup or HR paperwork for a new joiner).
class OnboardingTasksScreen extends ConsumerStatefulWidget {
  const OnboardingTasksScreen({super.key});

  @override
  ConsumerState<OnboardingTasksScreen> createState() => _OnboardingTasksScreenState();
}

class _OnboardingTasksScreenState extends ConsumerState<OnboardingTasksScreen> {
  bool _showClosed = false;

  Color _color(int s) {
    switch (s) {
      case OnbTaskStatus.done:
        return AppColors.success;
      case OnbTaskStatus.skipped:
        return Colors.grey;
      case OnbTaskStatus.inProgress:
        return AppColors.info;
      default:
        return AppColors.warning;
    }
  }

  Future<void> _update(OnbTask t, int status) async {
    String? notes;
    if (status == OnbTaskStatus.done || status == OnbTaskStatus.skipped) {
      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(status == OnbTaskStatus.done ? 'Mark as done' : 'Skip this task'),
          content: TextField(
            controller: ctrl,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Notes (optional)'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Back')),
            ElevatedButton(onPressed: () => Navigator.pop(d, true), child: const Text('Confirm')),
          ],
        ),
      );
      notes = ctrl.text.trim();
      ctrl.dispose();
      if (ok != true) return;
    }
    try {
      final r = await ref.read(extrasDataSourceProvider).setOnboardingTaskStatus(t, status, notes: notes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(r.message.isNotEmpty ? r.message : (r.success ? 'Updated' : 'Could not update')),
          backgroundColor: r.success ? Colors.green : Colors.red,
        ));
      }
      ref.invalidate(myOnboardingTasksProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AsyncValueView.messageOf(e)), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Onboarding tasks')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Open')),
                ButtonSegment(value: true, label: Text('Closed')),
              ],
              selected: {_showClosed},
              onSelectionChanged: (s) => setState(() => _showClosed = s.first),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(myOnboardingTasksProvider);
                await ref.read(myOnboardingTasksProvider.future);
              },
              child: AsyncValueView<List<OnbTask>>(
                value: ref.watch(myOnboardingTasksProvider),
                onRetry: () => ref.invalidate(myOnboardingTasksProvider),
                builder: (all) {
                  final tasks = all.where((t) => t.isOpen != _showClosed).toList();
                  if (tasks.isEmpty) {
                    return ListView(children: [
                      const SizedBox(height: 100),
                      EmptyStateWidget(
                        title: _showClosed ? 'No closed tasks' : 'No open tasks',
                        subtitle: _showClosed ? null : 'Tasks for new joiners assigned to you or your team appear here.',
                        icon: Icons.assignment_turned_in_outlined,
                      ),
                    ]);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final t = tasks[i];
                      return SurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(child: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                              StatusChip(label: OnbTaskStatus.label(t.statusId), color: _color(t.statusId)),
                            ]),
                            if ((t.description ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(t.description!, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              [
                                if (t.candidate.isNotEmpty) t.candidate,
                                if (t.teamName.isNotEmpty) t.teamName,
                                if (t.dueDate != null) 'Due ${formatYmd(t.dueDate, withYear: true)}',
                                if (t.joiningDate != null) 'Joins ${formatYmd(t.joiningDate, withYear: true)}',
                              ].join('  ·  '),
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            if ((t.notes ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('Note: ${t.notes}', style: const TextStyle(fontSize: 12.5)),
                              ),
                            if (t.isOpen)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(children: [
                                  if (t.statusId == OnbTaskStatus.pending)
                                    OutlinedButton(
                                      onPressed: () => _update(t, OnbTaskStatus.inProgress),
                                      child: const Text('Start'),
                                    ),
                                  const Spacer(),
                                  TextButton(onPressed: () => _update(t, OnbTaskStatus.skipped), child: const Text('Skip')),
                                  const SizedBox(width: 6),
                                  ElevatedButton(
                                    onPressed: () => _update(t, OnbTaskStatus.done),
                                    child: const Text('Mark done'),
                                  ),
                                ]),
                              ),
                          ],
                        ),
                      );
                    },
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
