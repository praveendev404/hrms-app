import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/work_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../widgets/common/async_value_view.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/ui_helpers.dart';

/// My skills: add a skill, rate your proficiency, keep it up to date.
class MySkillsScreen extends ConsumerWidget {
  const MySkillsScreen({super.key});

  Future<void> _openForm(BuildContext context, WidgetRef ref, int empId, {MySkill? skill}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SkillForm(empId: empId, existing: skill),
    );
    if (ok == true) ref.invalidate(mySkillsProvider(empId));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, int empId, MySkill s) async {
    try {
      final r = await ref.read(extrasDataSourceProvider).deleteMySkill(s.id);
      if (!r.success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(r.message.isNotEmpty ? r.message : 'Could not remove'), backgroundColor: Colors.red),
        );
      }
      ref.invalidate(mySkillsProvider(empId));
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
      appBar: AppBar(title: const Text('My skills')),
      floatingActionButton: empId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openForm(context, ref, empId),
              icon: const Icon(Icons.add),
              label: const Text('Add skill'),
            ),
      body: empId == null
          ? const Center(child: Text('Your account is not linked to an employee record.'))
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(mySkillsProvider(empId));
                await ref.read(mySkillsProvider(empId).future);
              },
              child: AsyncValueView<List<MySkill>>(
                value: ref.watch(mySkillsProvider(empId)),
                onRetry: () => ref.invalidate(mySkillsProvider(empId)),
                builder: (skills) {
                  if (skills.isEmpty) {
                    return ListView(children: const [
                      SizedBox(height: 100),
                      EmptyStateWidget(
                        title: 'No skills added yet',
                        subtitle: 'Add your skills so you can be matched to the right projects and learning.',
                        icon: Icons.psychology_alt_outlined,
                      ),
                    ]);
                  }
                  final byCat = <String, List<MySkill>>{};
                  for (final s in skills) {
                    byCat.putIfAbsent(s.category.isEmpty ? 'Other' : s.category, () => []).add(s);
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    children: [
                      for (final e in byCat.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 6),
                          child: SectionHeader(e.key),
                        ),
                        for (final s in e.value)
                          Dismissible(
                            key: ValueKey('skill-${s.id}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.only(right: 20),
                              alignment: Alignment.centerRight,
                              decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(16)),
                              child: const Icon(Icons.delete_outline, color: Colors.white),
                            ),
                            onDismissed: (_) => _delete(context, ref, empId, s),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: SurfaceCard(
                                onTap: () => _openForm(context, ref, empId, skill: s),
                                child: Row(children: [
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(s.skillName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      if ((s.notes ?? '').isNotEmpty)
                                        Text(s.notes!, maxLines: 1, overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                    ]),
                                  ),
                                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                    Row(children: [
                                      for (var i = 1; i <= 4; i++)
                                        Container(
                                          width: 10,
                                          height: 10,
                                          margin: const EdgeInsets.only(left: 4),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: i <= s.level ? AppColors.primary : AppColors.primaryContainer,
                                          ),
                                        ),
                                    ]),
                                    const SizedBox(height: 4),
                                    Text(kProficiency[s.level] ?? '',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  ]),
                                ]),
                              ),
                            ),
                          ),
                      ],
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Swipe a skill left to remove it.',
                            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

class _SkillForm extends ConsumerStatefulWidget {
  final int empId;
  final MySkill? existing;
  const _SkillForm({required this.empId, this.existing});

  @override
  ConsumerState<_SkillForm> createState() => _SkillFormState();
}

class _SkillFormState extends ConsumerState<_SkillForm> {
  late int? _skillId = widget.existing?.skillId;
  late int _level = widget.existing?.level ?? 2;
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  final _filter = TextEditingController();
  String _q = '';
  bool _busy = false;

  @override
  void dispose() {
    _notes.dispose();
    _filter.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_skillId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a skill.'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await ref.read(extrasDataSourceProvider).saveMySkill(
            id: widget.existing?.id,
            employeeId: widget.empId,
            skillId: _skillId!,
            level: _level,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r.message.isNotEmpty ? r.message : (r.success ? 'Saved' : 'Could not save')),
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

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(skillCatalogProvider).valueOrNull ?? const <SkillRef>[];
    final mine = (ref.watch(mySkillsProvider(widget.empId)).valueOrNull ?? const <MySkill>[]).map((s) => s.skillId).toSet();
    final options = catalog
        .where((s) => widget.existing != null ? s.id == widget.existing!.skillId : !mine.contains(s.id))
        .where((s) => _q.isEmpty || s.name.toLowerCase().contains(_q) || s.category.toLowerCase().contains(_q))
        .toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existing == null ? 'Add a skill' : 'Update skill',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (widget.existing == null) ...[
              TextField(
                controller: _filter,
                onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                decoration: const InputDecoration(labelText: 'Search skills', prefixIcon: Icon(Icons.search)),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final s in options)
                      RadioListTile<int>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: s.id,
                        groupValue: _skillId,
                        title: Text(s.name),
                        subtitle: Text(s.category, style: const TextStyle(fontSize: 11)),
                        onChanged: (v) => setState(() => _skillId = v),
                      ),
                    if (options.isEmpty)
                      const Padding(padding: EdgeInsets.all(12), child: Text('No matching skills.')),
                  ],
                ),
              ),
            ] else
              Text(widget.existing!.skillName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            const Text('Proficiency', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              for (final e in kProficiency.entries)
                ChoiceChip(label: Text(e.value), selected: _level == e.key, onSelected: (_) => setState(() => _level = e.key)),
            ]),
            const SizedBox(height: 12),
            TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes (optional)')),
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
