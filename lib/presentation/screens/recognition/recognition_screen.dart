import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/social_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/common/async_value_view.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/ui_helpers.dart';

/// Recognition wall, leaderboard, my recognitions, and give recognition.
class RecognitionScreen extends ConsumerWidget {
  const RecognitionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('Recognition'),
          bottom: const TabBar(tabs: [Tab(text: 'Wall'), Tab(text: 'Leaderboard'), Tab(text: 'Mine')]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            final ok = await showModalBottomSheet<bool>(
              context: context,
              isScrollControlled: true,
              builder: (_) => const _GiveForm(),
            );
            if (ok == true) {
              ref.invalidate(recognitionWallProvider);
              ref.invalidate(leaderboardProvider);
            }
          },
          icon: const Icon(Icons.emoji_events_outlined),
          label: const Text('Recognize'),
        ),
        body: const TabBarView(children: [
          _RecordList(mine: false),
          _Leaderboard(),
          _RecordList(mine: true),
        ]),
      ),
    );
  }
}

class _RecordList extends ConsumerWidget {
  final bool mine;
  const _RecordList({required this.mine});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = mine ? myRecognitionsProvider : recognitionWallProvider;
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(provider);
        await ref.read(provider.future);
      },
      child: AsyncValueView<List<RecognitionRecord>>(
        value: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        builder: (list) {
          if (list.isEmpty) {
            return ListView(children: [
              const SizedBox(height: 100),
              EmptyStateWidget(
                title: mine ? 'No recognitions yet' : 'The wall is empty',
                subtitle: 'Tap Recognize to appreciate a colleague.',
                icon: Icons.emoji_events_outlined,
              ),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final r = list[i];
              return SurfaceCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.badgeEmoji.isEmpty ? '🏅' : r.badgeEmoji, style: const TextStyle(fontSize: 30)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(TextSpan(children: [
                            TextSpan(text: r.senderName.trim(), style: const TextStyle(fontWeight: FontWeight.w600)),
                            const TextSpan(text: ' recognized '),
                            TextSpan(text: r.recipientName.trim(), style: const TextStyle(fontWeight: FontWeight.w600)),
                          ])),
                          const SizedBox(height: 2),
                          StatusChip(label: r.badgeName, color: AppColors.primary),
                          if ((r.message ?? '').isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(r.message!, style: TextStyle(color: Colors.grey.shade800)),
                          ],
                          const SizedBox(height: 4),
                          Text(formatDateTimeShort(r.recognizedOn),
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Leaderboard extends ConsumerWidget {
  const _Leaderboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(leaderboardProvider);
        await ref.read(leaderboardProvider.future);
      },
      child: AsyncValueView<List<LeaderEntry>>(
        value: ref.watch(leaderboardProvider),
        onRetry: () => ref.invalidate(leaderboardProvider),
        builder: (list) {
          if (list.isEmpty) {
            return ListView(children: const [
              SizedBox(height: 100),
              EmptyStateWidget(title: 'No data yet', icon: Icons.leaderboard_outlined),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final e = list[i];
              return SurfaceCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  SizedBox(
                    width: 32,
                    child: Text('#${e.rank}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.name.trim(), style: const TextStyle(fontWeight: FontWeight.w600)),
                        if ((e.designation ?? '').isNotEmpty)
                          Text(e.designation!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  Text('${e.count}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

class _GiveForm extends ConsumerStatefulWidget {
  const _GiveForm();

  @override
  ConsumerState<_GiveForm> createState() => _GiveFormState();
}

class _GiveFormState extends ConsumerState<_GiveForm> {
  final _search = TextEditingController();
  final _message = TextEditingController();
  Timer? _debounce;
  List<EmployeeOption> _results = [];
  EmployeeOption? _recipient;
  int? _badgeId;
  bool _busy = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _message.dispose();
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

  void _toast(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? Colors.red : Colors.green),
    );
  }

  Future<void> _submit() async {
    if (_recipient == null || _badgeId == null) {
      return _toast('Choose a colleague and a badge.', error: true);
    }
    setState(() => _busy = true);
    try {
      final r = await ref.read(socialDataSourceProvider).give(
            recipientId: _recipient!.id,
            badgeId: _badgeId!,
            message: _message.text.trim(),
          );
      if (!mounted) return;
      _toast(r.message.isNotEmpty ? r.message : (r.success ? 'Recognition sent' : 'Failed'), error: !r.success);
      if (r.success) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _toast(AsyncValueView.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final badges = ref.watch(recognitionBadgesProvider).valueOrNull ?? <RecognitionBadge>[];
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recognize a colleague', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (_recipient == null) ...[
              TextField(
                controller: _search,
                onChanged: _onSearch,
                decoration: const InputDecoration(labelText: 'Search colleague', prefixIcon: Icon(Icons.search)),
              ),
              for (final e in _results.take(6))
                ListTile(
                  dense: true,
                  title: Text(e.label),
                  subtitle: e.subLabel == null ? null : Text(e.subLabel!),
                  onTap: () => setState(() => _recipient = e),
                ),
            ] else
              InputChip(
                label: Text(_recipient!.label),
                onDeleted: () => setState(() {
                  _recipient = null;
                  _results = [];
                  _search.clear();
                }),
              ),
            const SizedBox(height: 12),
            const Text('Badge', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final b in badges)
                  ChoiceChip(
                    label: Text('${b.emoji} ${b.name}'),
                    selected: _badgeId == b.id,
                    onSelected: (_) => setState(() => _badgeId = b.id),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: _message, maxLines: 3, decoration: const InputDecoration(labelText: 'Message (optional)')),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Send'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
