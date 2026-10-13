import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/social_models.dart';
import '../../../data/models/work_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../widgets/common/async_value_view.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/ui_helpers.dart';
import 'performance_depth.dart';

void _toast(BuildContext context, String text, {bool error = true}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), backgroundColor: error ? Colors.red : Colors.green),
  );
}

/// My performance: goals, my review (self-assessment), and peer feedback.
class PerformanceScreen extends ConsumerWidget {
  /// 0 goals, 1 review, 2 feedback.
  final int initialTab;
  const PerformanceScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('Performance'),
          bottom: const TabBar(tabs: [Tab(text: 'Goals'), Tab(text: 'Review'), Tab(text: 'Feedback')]),
        ),
        body: const TabBarView(children: [_GoalsTab(), _ReviewTab(), _FeedbackTab()]),
      ),
    );
  }
}

// ---------------------------------------------------------------- goals

class _GoalsTab extends ConsumerWidget {
  const _GoalsTab();

  Color _color(int s) {
    switch (s) {
      case GoalStatus.approved:
        return AppColors.success;
      case GoalStatus.rejected:
        return AppColors.error;
      case GoalStatus.submitted:
        return AppColors.info;
      default:
        return AppColors.warning;
    }
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref, {PerfGoal? goal}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GoalForm(goal: goal),
    );
    if (ok == true) {
      ref.invalidate(myGoalsProvider);
      ref.invalidate(performanceSummaryProvider);
    }
  }

  Future<void> _submit(BuildContext context, WidgetRef ref, PerfGoal g) async {
    try {
      final r = await ref.read(extrasDataSourceProvider).setGoalStatus(g.id!, GoalStatus.submitted);
      if (context.mounted) _toast(context, r.message.isNotEmpty ? r.message : 'Submitted', error: !r.success);
      ref.invalidate(myGoalsProvider);
    } catch (e) {
      if (context.mounted) _toast(context, AsyncValueView.messageOf(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'goal-fab',
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Goal'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myGoalsProvider);
          await ref.read(myGoalsProvider.future);
        },
        child: AsyncValueView<List<PerfGoal>>(
          value: ref.watch(myGoalsProvider),
          onRetry: () => ref.invalidate(myGoalsProvider),
          builder: (goals) {
            if (goals.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 100),
                EmptyStateWidget(
                  title: 'No goals yet',
                  subtitle: 'Add goals for the current cycle and submit them for approval.',
                  icon: Icons.flag_outlined,
                ),
              ]);
            }
            // Group by cycle.
            final byCycle = <String, List<PerfGoal>>{};
            for (final g in goals) {
              byCycle.putIfAbsent(g.cycleName.isEmpty ? 'Goals' : g.cycleName, () => []).add(g);
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                for (final e in byCycle.entries) ...[
                  Row(children: [
                    Expanded(child: SectionHeader(e.key)),
                    Text('${e.value.fold<int>(0, (a, g) => a + g.weight)}% weight',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ]),
                  const SizedBox(height: 6),
                  for (final g in e.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SurfaceCard(
                        onTap: g.canEdit ? () => _openForm(context, ref, goal: g) : null,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(child: Text(g.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                              StatusChip(label: g.statusName.isEmpty ? 'Draft' : g.statusName, color: _color(g.statusId)),
                            ]),
                            if ((g.description ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(g.description!, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                            ],
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 4, children: [
                              StatusChip(label: '${g.weight}% weight', color: AppColors.primary),
                              StatusChip(label: g.goalTypeId == 2 ? 'Aspirational' : 'Core', color: AppColors.tertiary),
                              if ((g.target ?? '').isNotEmpty)
                                StatusChip(label: 'Target: ${g.target}', color: Colors.blueGrey),
                              if ((g.achieved ?? '').isNotEmpty)
                                StatusChip(label: 'Achieved: ${g.achieved}', color: AppColors.success),
                            ]),
                            if (g.id != null)
                              Align(
                                alignment: Alignment.centerRight,
                                child: Wrap(children: [
                                  TextButton.icon(
                                    onPressed: () => showKeyResults(context, g),
                                    icon: const Icon(Icons.track_changes_rounded, size: 16),
                                    label: const Text('Key results'),
                                  ),
                                  if (g.canEdit)
                                    TextButton.icon(
                                      onPressed: () => _submit(context, ref, g),
                                      icon: const Icon(Icons.send_rounded, size: 16),
                                      label: const Text('Submit for approval'),
                                    ),
                                ]),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GoalForm extends ConsumerStatefulWidget {
  final PerfGoal? goal;
  const _GoalForm({this.goal});

  @override
  ConsumerState<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends ConsumerState<_GoalForm> {
  late final _title = TextEditingController(text: widget.goal?.title ?? '');
  late final _desc = TextEditingController(text: widget.goal?.description ?? '');
  late final _target = TextEditingController(text: widget.goal?.target ?? '');
  late int? _cycleId = widget.goal?.cycleId;
  late int _type = widget.goal?.goalTypeId ?? 1;
  late double _weight = (widget.goal?.weight ?? 10).toDouble();
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final empId = ref.read(userProfileProvider).profile?.employeeId;
    if (empId == null) return _toast(context, 'Your account is not linked to an employee record.');
    if (_cycleId == null) return _toast(context, 'Choose a review cycle.');
    if (_title.text.trim().isEmpty) return _toast(context, 'Give the goal a title.');
    setState(() => _busy = true);
    try {
      final r = await ref.read(extrasDataSourceProvider).saveGoal(
            PerfGoal(
              id: widget.goal?.id,
              cycleId: _cycleId!,
              title: _title.text.trim(),
              description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
              goalTypeId: _type,
              weight: _weight.round(),
              target: _target.text.trim().isEmpty ? null : _target.text.trim(),
              achieved: widget.goal?.achieved,
              statusId: widget.goal?.statusId ?? GoalStatus.draft,
            ),
            empId,
          );
      if (!mounted) return;
      _toast(context, r.message.isNotEmpty ? r.message : (r.success ? 'Saved' : 'Could not save'), error: !r.success);
      if (r.success) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _toast(context, AsyncValueView.messageOf(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cycles = ref.watch(knownCyclesProvider).valueOrNull ?? const <PerfCycleRef>[];
    if (_cycleId == null && cycles.isNotEmpty) _cycleId = cycles.first.id;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.goal == null ? 'New goal' : 'Edit goal',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            if (cycles.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(12)),
                child: const Text('No open review cycle was found for you. Goals can be added once HR opens a cycle.'),
              )
            else
              DropdownButtonFormField<int>(
                value: cycles.any((c) => c.id == _cycleId) ? _cycleId : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Review cycle'),
                items: [for (final c in cycles) DropdownMenuItem(value: c.id, child: Text(c.name))],
                onChanged: (v) => setState(() => _cycleId = v),
              ),
            const SizedBox(height: 12),
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Goal title')),
            const SizedBox(height: 12),
            TextField(controller: _desc, maxLines: 3, decoration: const InputDecoration(labelText: 'Description (optional)')),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('Core')),
                ButtonSegment(value: 2, label: Text('Aspirational')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Weight', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${_weight.round()}%', style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
            Slider(value: _weight, min: 5, max: 100, divisions: 19, onChanged: (v) => setState(() => _weight = v)),
            TextField(controller: _target, decoration: const InputDecoration(labelText: 'Target (optional)')),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_busy || cycles.isEmpty) ? null : _save,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save goal'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- review

class _ReviewTab extends ConsumerWidget {
  const _ReviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myReviewsProvider);
        await ref.read(myReviewsProvider.future);
      },
      child: AsyncValueView<List<PerfReview>>(
        value: ref.watch(myReviewsProvider),
        onRetry: () => ref.invalidate(myReviewsProvider),
        builder: (reviews) {
          if (reviews.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 100),
              EmptyStateWidget(
                title: 'No reviews yet',
                subtitle: 'Your review appears here when a performance cycle starts.',
                icon: Icons.rate_review_outlined,
              ),
            ]);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final r in reviews)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.cycleName.isEmpty ? 'Review' : r.cycleName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        StatusChip(
                          label: ReviewStatus.label(r.statusId),
                          color: r.statusId == ReviewStatus.finalized ? AppColors.success : AppColors.info,
                        ),
                        const Divider(height: 24),
                        _ScoreRow('Your rating', r.selfScore, r.selfComments),
                        if (r.managerScore != null) _ScoreRow('Manager rating', r.managerScore, r.managerComments),
                        if (r.finalScore != null) _ScoreRow('Final rating', r.finalScore, r.finalComments),
                        if (r.id != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => showReviewDetail(context, r),
                              icon: const Icon(Icons.groups_2_outlined, size: 18),
                              label: const Text('Competencies & 360° feedback'),
                            ),
                          ),
                        if (r.canSelfAssess)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final ok = await showModalBottomSheet<bool>(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (_) => _SelfAssessmentForm(review: r),
                                  );
                                  if (ok == true) {
                                    ref.invalidate(myReviewsProvider);
                                    ref.invalidate(performanceSummaryProvider);
                                  }
                                },
                                icon: const Icon(Icons.edit_note_rounded),
                                label: const Text('Do self-assessment'),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final int? score;
  final String? comments;
  const _ScoreRow(this.label, this.score, this.comments);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          if (score == null)
            const Text('Not rated yet')
          else
            Row(children: [
              for (var i = 1; i <= 5; i++)
                Icon(i <= score! ? Icons.star_rounded : Icons.star_outline_rounded, size: 20, color: AppColors.warning),
              const SizedBox(width: 8),
              Flexible(child: Text(kRatingLabels[score] ?? '$score', style: const TextStyle(fontWeight: FontWeight.w600))),
            ]),
          if ((comments ?? '').isNotEmpty) Text(comments!, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
        ],
      ),
    );
  }
}

class _SelfAssessmentForm extends ConsumerStatefulWidget {
  final PerfReview review;
  const _SelfAssessmentForm({required this.review});

  @override
  ConsumerState<_SelfAssessmentForm> createState() => _SelfAssessmentFormState();
}

class _SelfAssessmentFormState extends ConsumerState<_SelfAssessmentForm> {
  int _score = 3;
  final _comments = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _comments.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final empId = ref.read(userProfileProvider).profile?.employeeId;
    if (empId == null) return _toast(context, 'Your account is not linked to an employee record.');
    if (_comments.text.trim().isEmpty) return _toast(context, 'Add a short summary of your year.');
    setState(() => _busy = true);
    try {
      final r = await ref.read(extrasDataSourceProvider).submitSelfAssessment(
            review: widget.review,
            employeeId: empId,
            score: _score,
            comments: _comments.text.trim(),
          );
      if (!mounted) return;
      _toast(context, r.message.isNotEmpty ? r.message : (r.success ? 'Submitted' : 'Failed'), error: !r.success);
      if (r.success) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _toast(context, AsyncValueView.messageOf(e));
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
            const Text('Self-assessment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(widget.review.cycleName, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    iconSize: 38,
                    onPressed: () => setState(() => _score = i),
                    icon: Icon(i <= _score ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.warning),
                  ),
              ],
            ),
            Center(child: Text(kRatingLabels[_score]!, style: const TextStyle(fontWeight: FontWeight.w700))),
            const SizedBox(height: 12),
            TextField(
              controller: _comments,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'How did the year go?'),
            ),
            const SizedBox(height: 8),
            Text('You cannot change this after submitting.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Submit self-assessment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- feedback

class _FeedbackTab extends ConsumerStatefulWidget {
  const _FeedbackTab();

  @override
  ConsumerState<_FeedbackTab> createState() => _FeedbackTabState();
}

class _FeedbackTabState extends ConsumerState<_FeedbackTab> {
  bool _received = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fb-fab',
        onPressed: () async {
          final ok = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const _GiveFeedbackForm(),
          );
          if (ok == true) ref.invalidate(feedbackProvider(false));
        },
        icon: const Icon(Icons.rate_review_outlined),
        label: const Text('Give'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Received')),
                ButtonSegment(value: false, label: Text('Given')),
              ],
              selected: {_received},
              onSelectionChanged: (s) => setState(() => _received = s.first),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(feedbackProvider(_received));
                await ref.read(feedbackProvider(_received).future);
              },
              child: AsyncValueView<List<PerfFeedback>>(
                value: ref.watch(feedbackProvider(_received)),
                onRetry: () => ref.invalidate(feedbackProvider(_received)),
                builder: (list) {
                  if (list.isEmpty) {
                    return ListView(children: [
                      const SizedBox(height: 80),
                      EmptyStateWidget(
                        title: _received ? 'No feedback received yet' : 'You have not given feedback yet',
                        icon: Icons.forum_outlined,
                      ),
                    ]);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final f = list[i];
                      final who = _received
                          ? (f.isAnonymous || f.fromName.isEmpty ? 'Anonymous' : f.fromName)
                          : f.toName;
                      return SurfaceCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              UserAvatar(name: who, radius: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(_received ? 'From $who' : 'To $who', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text(formatDateTimeShort(f.createdDate),
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                ]),
                              ),
                              Row(children: [
                                for (var s = 1; s <= 5; s++)
                                  Icon(s <= f.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                                      size: 16, color: AppColors.warning),
                              ]),
                            ]),
                            if ((f.category ?? '').isNotEmpty) ...[
                              const SizedBox(height: 8),
                              StatusChip(label: f.category!, color: AppColors.primary),
                            ],
                            if (f.comments.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(f.comments),
                            ],
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

class _GiveFeedbackForm extends ConsumerStatefulWidget {
  const _GiveFeedbackForm();

  @override
  ConsumerState<_GiveFeedbackForm> createState() => _GiveFeedbackFormState();
}

class _GiveFeedbackFormState extends ConsumerState<_GiveFeedbackForm> {
  static const _categories = ['Communication', 'Leadership', 'Technical Skills', 'Teamwork', 'Attitude', 'Other'];

  final _search = TextEditingController();
  final _comments = TextEditingController();
  Timer? _debounce;
  List<EmployeeOption> _results = [];
  EmployeeOption? _to;
  String _category = _categories.first;
  int _rating = 4;
  bool _anonymous = false;
  bool _busy = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _comments.dispose();
    super.dispose();
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    if (text.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final r = await ref.read(socialDataSourceProvider).searchEmployees(text.trim());
        if (mounted) setState(() => _results = r);
      } catch (_) {
        if (mounted) setState(() => _results = []);
      }
    });
  }

  Future<void> _submit() async {
    final empId = ref.read(userProfileProvider).profile?.employeeId;
    if (empId == null) return _toast(context, 'Your account is not linked to an employee record.');
    if (_to == null) return _toast(context, 'Choose a colleague.');
    if (_to!.id == empId) return _toast(context, 'You cannot give feedback to yourself.');
    if (_comments.text.trim().isEmpty) return _toast(context, 'Write a few words of feedback.');
    setState(() => _busy = true);
    try {
      final r = await ref.read(extrasDataSourceProvider).giveFeedback(
            fromEmployeeId: empId,
            toEmployeeId: _to!.id,
            category: _category,
            rating: _rating,
            comments: _comments.text.trim(),
            anonymous: _anonymous,
          );
      if (!mounted) return;
      _toast(context, r.message.isNotEmpty ? r.message : (r.success ? 'Feedback sent' : 'Failed'), error: !r.success);
      if (r.success) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _toast(context, AsyncValueView.messageOf(e));
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
            const Text('Give feedback', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (_to == null) ...[
              TextField(
                controller: _search,
                onChanged: _onSearch,
                decoration: const InputDecoration(labelText: 'Search colleague', prefixIcon: Icon(Icons.search)),
              ),
              for (final e in _results.take(5))
                ListTile(
                  dense: true,
                  title: Text(e.label),
                  subtitle: e.subLabel == null ? null : Text(e.subLabel!),
                  onTap: () => setState(() => _to = e),
                ),
            ] else
              InputChip(
                label: Text(_to!.label),
                onDeleted: () => setState(() {
                  _to = null;
                  _results = [];
                  _search.clear();
                }),
              ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in _categories)
                ChoiceChip(label: Text(c), selected: _category == c, onSelected: (_) => setState(() => _category = c)),
            ]),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    iconSize: 34,
                    onPressed: () => setState(() => _rating = i),
                    icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.warning),
                  ),
              ],
            ),
            TextField(controller: _comments, maxLines: 4, decoration: const InputDecoration(labelText: 'Feedback')),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Send anonymously'),
              value: _anonymous,
              onChanged: (v) => setState(() => _anonymous = v),
            ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Send feedback'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
