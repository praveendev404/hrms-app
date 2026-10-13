import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/leave_models.dart';
import '../../../data/models/work_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/common/async_value_view.dart';
import '../../widgets/common/ui_helpers.dart';

Color _krColor(int id) => switch (id) {
      KrStatus.atRisk => AppColors.warning,
      KrStatus.behind => AppColors.error,
      KrStatus.completed => AppColors.success,
      _ => AppColors.info,
    };

String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

void _toast(BuildContext c, String t, {bool error = true}) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(t), backgroundColor: error ? Colors.red : Colors.green));

Future<void> showKeyResults(BuildContext context, PerfGoal goal) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _KeyResultsSheet(goal: goal),
    );

Future<void> showReviewDetail(BuildContext context, PerfReview review) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReviewDetailSheet(review: review),
    );

class _KeyResultsSheet extends ConsumerWidget {
  final PerfGoal goal;
  const _KeyResultsSheet({required this.goal});

  Future<void> _run(BuildContext context, WidgetRef ref, Future<ActionResult> Function() call) async {
    try {
      final r = await call();
      if (context.mounted && (!r.success || r.message.isNotEmpty)) _toast(context, r.message, error: !r.success);
      ref.invalidate(keyResultsProvider(goal.id!));
    } catch (e) {
      if (context.mounted) _toast(context, AsyncValueView.messageOf(e));
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, PerfKeyResult? k) async {
    final title = TextEditingController(text: k?.title ?? '');
    final unit = TextEditingController(text: k?.unit ?? '');
    final start = TextEditingController(text: k == null ? '0' : _num(k.start));
    final target = TextEditingController(text: k == null ? '' : _num(k.target));
    final current = TextEditingController(text: k == null ? '0' : _num(k.current));
    var status = k?.statusId ?? KrStatus.onTrack;
    // Editing an existing one only moves progress; its definition stays fixed.
    final progressOnly = k != null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setS) => AlertDialog(
          title: Text(k == null ? 'Add key result' : 'Update progress'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (!progressOnly) ...[
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Key result')),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: start,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Start'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: target,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Target'),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                TextField(controller: unit, decoration: const InputDecoration(labelText: 'Unit (optional)')),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: current,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'Current value', suffixText: k?.unit),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                for (final s in const [KrStatus.onTrack, KrStatus.atRisk, KrStatus.behind, KrStatus.completed])
                  ChoiceChip(
                    label: Text(KrStatus.label(s)),
                    selected: status == s,
                    onSelected: (_) => setS(() => status = s),
                  ),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(d, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;

    final cur = double.tryParse(current.text.trim());
    if (cur == null) return _toast(context, 'Enter the current value as a number.');
    final ds = ref.read(extrasDataSourceProvider);
    if (k != null) {
      await _run(context, ref, () => ds.updateKeyResultProgress(k.id, cur, status));
      return;
    }
    final st = double.tryParse(start.text.trim());
    final tg = double.tryParse(target.text.trim());
    if (title.text.trim().isEmpty || st == null || tg == null) {
      return _toast(context, 'Give the key result a title, a start and a target value.');
    }
    if (st == tg) return _toast(context, 'Start and target must be different.');
    await _run(
      context,
      ref,
      () => ds.saveKeyResult(PerfKeyResult(
        id: 0,
        goalId: goal.id!,
        title: title.text.trim(),
        unit: unit.text.trim().isEmpty ? null : unit.text.trim(),
        start: st,
        target: tg,
        current: cur,
        statusId: status,
      )),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, PerfKeyResult k) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Remove key result?'),
        content: Text(k.title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Remove')),
        ],
      ),
    );
    if (go == true && context.mounted) {
      await _run(context, ref, () => ref.read(extrasDataSourceProvider).deleteKeyResult(k.id));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(keyResultsProvider(goal.id!));
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(goal.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('Key results', style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 10),
            Flexible(
              child: AsyncValueView<List<PerfKeyResult>>(
                compact: true,
                value: value,
                onRetry: () => ref.invalidate(keyResultsProvider(goal.id!)),
                builder: (list) => list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('No key results yet. Add measurable steps for this goal.',
                              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
                        ),
                      )
                    : ListView(shrinkWrap: true, children: [
                        for (final k in list)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: SurfaceCard(
                              onTap: () => _edit(context, ref, k),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(child: Text(k.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                                  StatusChip(label: KrStatus.label(k.statusId), color: _krColor(k.statusId)),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.delete_outline, size: 20),
                                    tooltip: 'Remove',
                                    onPressed: () => _remove(context, ref, k),
                                  ),
                                ]),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: k.progress,
                                    minHeight: 8,
                                    color: _krColor(k.statusId),
                                    backgroundColor: const Color(0xFFEEF1F6),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_num(k.current)} of ${_num(k.target)}${k.unit == null ? '' : ' ${k.unit}'} · ${(k.progress * 100).round()}%',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                              ]),
                            ),
                          ),
                      ]),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () => _edit(context, ref, null),
                icon: const Icon(Icons.add),
                label: const Text('Add key result'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Read-only: competency ratings on my review and the 360 feedback others submitted.
class _ReviewDetailSheet extends ConsumerWidget {
  final PerfReview review;
  const _ReviewDetailSheet({required this.review});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = review.id!;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 20), shrinkWrap: true, children: [
          Text(review.cycleName.isEmpty ? 'Review' : review.cycleName,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          const SectionHeader('Competencies'),
          const SizedBox(height: 6),
          AsyncValueView<List<CompetencyRating>>(
            compact: true,
            value: ref.watch(competencyRatingsProvider(id)),
            onRetry: () => ref.invalidate(competencyRatingsProvider(id)),
            builder: (list) {
              final rated = list.where((c) => c.value > 0).toList();
              if (rated.isEmpty) return _none('No competency ratings have been recorded yet.');
              return Column(children: [
                for (final c in rated)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SurfaceCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                          _Stars(c.value),
                        ]),
                        if (c.group.isNotEmpty) Text(c.group, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        if ((c.comments ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(c.comments!, style: const TextStyle(fontSize: 13)),
                        ],
                      ]),
                    ),
                  ),
              ]);
            },
          ),
          const SizedBox(height: 14),
          const SectionHeader('360° feedback'),
          const SizedBox(height: 6),
          AsyncValueView<List<Perf360Feedback>>(
            compact: true,
            value: ref.watch(feedback360Provider(id)),
            onRetry: () => ref.invalidate(feedback360Provider(id)),
            builder: (list) {
              final done = list.where((f) => f.submitted).toList();
              if (done.isEmpty) return _none('No 360° feedback has been submitted for this review.');
              return Column(children: [
                for (final f in done)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SurfaceCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(
                            child: Text(f.reviewerType.isEmpty ? 'Reviewer' : f.reviewerType,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          if (f.score != null) _Stars(f.score!.round()),
                        ]),
                        if ((f.strengths ?? '').isNotEmpty) _Block('Strengths', f.strengths!),
                        if ((f.improvements ?? '').isNotEmpty) _Block('To improve', f.improvements!),
                        if ((f.comments ?? '').isNotEmpty) _Block('Comments', f.comments!),
                      ]),
                    ),
                  ),
              ]);
            },
          ),
        ]),
      ),
    );
  }

  Widget _none(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(t, style: TextStyle(color: Colors.grey.shade600)),
      );
}

class _Stars extends StatelessWidget {
  final int value;
  const _Stars(this.value);

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 1; i <= 5; i++)
          Icon(i <= value ? Icons.star_rounded : Icons.star_outline_rounded, size: 16, color: AppColors.warning),
      ]);
}

class _Block extends StatelessWidget {
  final String label;
  final String text;
  const _Block(this.label, this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
          Text(text, style: const TextStyle(fontSize: 13)),
        ]),
      );
}
