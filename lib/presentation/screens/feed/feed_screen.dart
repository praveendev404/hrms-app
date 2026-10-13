import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/file_pick.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/extras_models.dart';
import '../../navigation/app_menu.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../widgets/common/async_value_view.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/ui_helpers.dart';

/// Company posts and announcements, with like and comments.
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  void _error(BuildContext context, Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AsyncValueView.messageOf(e)), backgroundColor: Colors.red),
    );
  }

  Future<void> _toggleLike(BuildContext context, WidgetRef ref, FeedPost p) async {
    final empId = ref.read(userProfileProvider).profile?.employeeId;
    if (empId == null) return;
    try {
      final r = await ref.read(extrasDataSourceProvider).like(feedId: p.id, employeeId: empId);
      if (!r.success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(r.message.isNotEmpty ? r.message : 'Could not react'), backgroundColor: Colors.red),
        );
      }
      ref.invalidate(feedProvider);
    } catch (e) {
      if (context.mounted) _error(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canPost = menuHas(ref, 'feed/list');
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Posts & announcements')),
      floatingActionButton: canPost
          ? FloatingActionButton.extended(
              onPressed: () async {
                final ok = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const _PostForm(),
                );
                if (ok == true) ref.invalidate(feedProvider);
              },
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Post'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(feedProvider);
          await ref.read(feedProvider.future);
        },
        child: AsyncValueView<List<FeedPost>>(
          value: ref.watch(feedProvider),
          onRetry: () => ref.invalidate(feedProvider),
          builder: (list) {
            if (list.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 100),
                EmptyStateWidget(title: 'No posts yet', icon: Icons.campaign_outlined),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final p = list[i];
                return SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        if (p.feedTypeName.isNotEmpty) StatusChip(label: p.feedTypeName, color: AppColors.primary),
                        const Spacer(),
                        Text(formatDateTimeShort(p.createdDate), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      ]),
                      const SizedBox(height: 8),
                      Text(p.header, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      if (p.plainBody.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(p.plainBody, style: TextStyle(color: Colors.grey.shade800, height: 1.35)),
                      ],
                      if ((p.authorName ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('— ${p.authorName!.trim()}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                      const Divider(height: 20),
                      Row(children: [
                        TextButton.icon(
                          onPressed: () => _toggleLike(context, ref, p),
                          icon: Icon(p.liked ? Icons.thumb_up : Icons.thumb_up_outlined, size: 18),
                          label: Text('${p.reactionsCount}'),
                        ),
                        TextButton.icon(
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => _CommentsSheet(post: p),
                          ).then((_) => ref.invalidate(feedProvider)),
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          label: Text('${p.commentsCount}'),
                        ),
                      ]),
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

class _CommentsSheet extends ConsumerStatefulWidget {
  final FeedPost post;
  const _CommentsSheet({required this.post});

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _text = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final empId = ref.read(userProfileProvider).profile?.employeeId;
    final value = _text.text.trim();
    if (empId == null || value.isEmpty) return;
    setState(() => _busy = true);
    try {
      final r = await ref.read(extrasDataSourceProvider).addComment(feedId: widget.post.id, employeeId: empId, text: value);
      if (r.success) {
        _text.clear();
        ref.invalidate(feedCommentsProvider(widget.post.id));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(r.message.isNotEmpty ? r.message : 'Could not post comment'), backgroundColor: Colors.red),
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
    final comments = ref.watch(feedCommentsProvider(widget.post.id));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Comments', style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
            Expanded(
              child: AsyncValueView<List<FeedComment>>(
                value: comments,
                onRetry: () => ref.invalidate(feedCommentsProvider(widget.post.id)),
                builder: (list) {
                  if (list.isEmpty) {
                    return const Center(child: Text('Be the first to comment.'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 16),
                    itemBuilder: (_, i) {
                      final c = list[i];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.author, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(c.text),
                          Text(formatDateTimeShort(c.at), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(hintText: 'Write a comment'),
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : _send,
                  icon: const Icon(Icons.send, color: AppColors.primary),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostForm extends ConsumerStatefulWidget {
  const _PostForm();

  @override
  ConsumerState<_PostForm> createState() => _PostFormState();
}

class _PostFormState extends ConsumerState<_PostForm> {
  final _header = TextEditingController();
  final _body = TextEditingController();
  int _type = 2; // announcement
  DateTime? _expires;
  bool _notify = true;
  bool _busy = false;
  File? _file;

  @override
  void dispose() {
    _header.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_header.text.trim().isEmpty || _body.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a title and some text.'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await ref.read(extrasDataSourceProvider).createFeed(
            header: _header.text.trim(),
            body: _body.text.trim(),
            feedTypeId: _type,
            expireDate: _expires == null
                ? null
                : '${_expires!.year}-${_expires!.month.toString().padLeft(2, '0')}-${_expires!.day.toString().padLeft(2, '0')}',
            notifyEmployees: _notify,
            attachment: _file,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r.message.isNotEmpty ? r.message : (r.success ? 'Posted' : 'Could not post')),
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
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New post', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 2, label: Text('Announcement'), icon: Icon(Icons.campaign_outlined)),
                ButtonSegment(value: 1, label: Text('Post'), icon: Icon(Icons.article_outlined)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 12),
            TextField(controller: _header, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            TextField(controller: _body, maxLines: 5, decoration: const InputDecoration(labelText: 'Message')),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _expires ?? DateTime.now().add(const Duration(days: 7)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                );
                if (d != null) setState(() => _expires = d);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Visible until (optional)',
                  suffixIcon: _expires == null
                      ? const Icon(Icons.event_outlined, size: 18)
                      : IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _expires = null)),
                ),
                child: Text(_expires == null ? 'No end date' : '${_expires!.day}/${_expires!.month}/${_expires!.year}'),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: _file == null
                  ? TextButton.icon(
                      onPressed: () async {
                        try {
                          final f = await pickAttachment();
                          if (f != null) setState(() => _file = f);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(AsyncValueView.messageOf(e)), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.attach_file_rounded, size: 18),
                      label: const Text('Attach a file'),
                    )
                  : InputChip(
                      avatar: const Icon(Icons.attach_file_rounded, size: 16),
                      label: Text(_file!.path.split(Platform.pathSeparator).last, overflow: TextOverflow.ellipsis),
                      onDeleted: () => setState(() => _file = null),
                    ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Notify employees'),
              value: _notify,
              onChanged: (v) => setState(() => _notify = v),
            ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Publish'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
