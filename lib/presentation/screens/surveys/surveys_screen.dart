import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/social_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/common/async_value_view.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/ui_helpers.dart';

/// Surveys assigned to me.
class SurveysScreen extends ConsumerWidget {
  const SurveysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Surveys')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(mySurveysProvider);
          await ref.read(mySurveysProvider.future);
        },
        child: AsyncValueView<List<Survey>>(
          value: ref.watch(mySurveysProvider),
          onRetry: () => ref.invalidate(mySurveysProvider),
          builder: (list) {
            if (list.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 100),
                EmptyStateWidget(title: 'No surveys', icon: Icons.poll_outlined),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final s = list[i];
                return SurfaceCard(
                  onTap: s.isCompleted
                      ? null
                      : () async {
                          final done = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(builder: (_) => SurveyFormScreen(survey: s)),
                          );
                          if (done == true) ref.invalidate(mySurveysProvider);
                        },
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                          if ((s.description ?? '').isNotEmpty)
                            Text(s.description!, maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          Text(
                            [
                              '${s.questions.length} question(s)',
                              if (s.isAnonymous) 'Anonymous',
                              if (s.endsOn != null) 'Ends ${formatYmd(s.endsOn, withYear: true)}',
                            ].join('  ·  '),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    StatusChip(
                      label: s.isCompleted ? 'Done' : 'Take',
                      color: s.isCompleted ? AppColors.success : AppColors.primary,
                    ),
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

class SurveyFormScreen extends ConsumerStatefulWidget {
  final Survey survey;
  const SurveyFormScreen({super.key, required this.survey});

  @override
  ConsumerState<SurveyFormScreen> createState() => _SurveyFormScreenState();
}

class _SurveyFormScreenState extends ConsumerState<SurveyFormScreen> {
  final Map<int, dynamic> _answers = {};
  final Map<int, TextEditingController> _text = {};
  bool _busy = false;

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final payload = <Map<String, dynamic>>[];
    var missing = 0;
    for (final q in widget.survey.questions) {
      final v = q.typeId == QuestionType.text ? _text[q.id]?.text.trim() : _answers[q.id];
      if (q.isRequired && (v == null || v == '')) missing++;
      payload.add({
        'questionId': q.id,
        if (q.typeId == QuestionType.text) 'textAnswer': v ?? '',
        if (q.typeId == QuestionType.mcq && v != null) 'selectedOptionId': v,
        if ((q.typeId == QuestionType.rating5 || q.typeId == QuestionType.rating10) && v != null) 'numericAnswer': v,
      });
    }
    if (missing > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please answer all required questions ($missing remaining).'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await ref.read(socialDataSourceProvider).submitSurvey(widget.survey.id, payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r.message.isNotEmpty ? r.message : (r.success ? 'Thank you!' : 'Could not submit')),
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

  Widget _input(SurveyQuestion q) {
    switch (q.typeId) {
      case QuestionType.rating5:
      case QuestionType.rating10:
        final max = q.typeId == QuestionType.rating5 ? 5 : 10;
        final min = q.typeId == QuestionType.rating5 ? 1 : 0;
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var n = min; n <= max; n++)
              ChoiceChip(
                label: Text('$n'),
                selected: _answers[q.id] == n,
                onSelected: (_) => setState(() => _answers[q.id] = n),
              ),
          ],
        );
      case QuestionType.mcq:
        return Column(
          children: [
            for (final o in q.options)
              RadioListTile<int>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: o.id,
                groupValue: _answers[q.id] as int?,
                title: Text(o.text),
                onChanged: (v) => setState(() => _answers[q.id] = v),
              ),
          ],
        );
      default:
        return TextField(
          controller: _text.putIfAbsent(q.id, TextEditingController.new),
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Your answer'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.survey;
    return Scaffold(
      appBar: AppBar(title: Text(s.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (s.isAnonymous)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Your response is anonymous.', style: TextStyle(color: Colors.grey.shade600)),
            ),
          for (final q in s.questions)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${q.text}${q.isRequired ? ' *' : ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _input(q),
                ],
              ),
            ),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit'),
            ),
          ),
        ],
      ),
    );
  }
}
