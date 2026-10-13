import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/file_pick.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/dropdown_option_model.dart';
import '../../../data/models/work_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../widgets/common/async_value_view.dart';
import '../../widgets/common/ui_helpers.dart';

/// A ticket's conversation, status and approvals. Anyone on the ticket can comment;
/// changing the status is allowed by the server for assignees, approvers and admins.
class TicketActivityScreen extends ConsumerStatefulWidget {
  final int ticketId;
  final String ticketNo;
  const TicketActivityScreen({super.key, required this.ticketId, required this.ticketNo});

  @override
  ConsumerState<TicketActivityScreen> createState() => _TicketActivityScreenState();
}

class _TicketActivityScreenState extends ConsumerState<TicketActivityScreen> {
  final _text = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _toast(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: error ? Colors.red : Colors.green),
    );
  }

  Future<void> _send() async {
    final value = _text.text.trim();
    if (value.isEmpty) return;
    setState(() => _busy = true);
    try {
      final r = await ref.read(extrasDataSourceProvider).addTicketComment(widget.ticketId, value);
      if (r.success) {
        _text.clear();
        ref.invalidate(ticketActivityProvider(widget.ticketId));
      } else {
        _toast(r.message.isNotEmpty ? r.message : 'Could not post', error: true);
      }
    } catch (e) {
      _toast(AsyncValueView.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _attach() async {
    try {
      final file = await pickAttachment();
      if (file == null) return;
      setState(() => _busy = true);
      final r = await ref.read(extrasDataSourceProvider).addTicketAttachment(widget.ticketId, file);
      _toast(r.message.isNotEmpty ? r.message : (r.success ? 'File attached' : 'Could not attach'), error: !r.success);
      ref.invalidate(ticketActivityProvider(widget.ticketId));
    } catch (e) {
      _toast(AsyncValueView.messageOf(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAttachment(TicketAttachment a) async {
    try {
      final path = await ref.read(extrasDataSourceProvider).downloadTicketAttachment(widget.ticketId, a);
      final res = await OpenFilex.open(path);
      if (res.type != ResultType.done) _toast('No app on this phone can open ${a.fileName}.', error: true);
    } catch (e) {
      _toast(AsyncValueView.messageOf(e), error: true);
    }
  }

  Future<void> _removeAttachment(TicketAttachment a) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Remove attachment?'),
        content: Text(a.fileName),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Remove')),
        ],
      ),
    );
    if (go != true) return;
    try {
      final r = await ref.read(extrasDataSourceProvider).removeTicketAttachment(widget.ticketId, a.id);
      _toast(r.message.isNotEmpty ? r.message : (r.success ? 'Removed' : 'Could not remove'), error: !r.success);
      ref.invalidate(ticketActivityProvider(widget.ticketId));
    } catch (e) {
      _toast(AsyncValueView.messageOf(e), error: true);
    }
  }

  Future<void> _changeStatus(TicketActivity a) async {
    final options = await ref.read(ticketStatusOptionsProvider.future);
    if (!mounted) return;
    int? picked = a.statusId;
    final noteCtrl = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(sheet).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Change status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final DropdownOptionModel o in options)
                  ChoiceChip(label: Text(o.label), selected: picked == o.value, onSelected: (_) => setSheet(() => picked = o.value)),
              ]),
              const SizedBox(height: 12),
              TextField(controller: noteCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Comment (optional)')),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(onPressed: () => Navigator.pop(sheet, true), child: const Text('Update')),
              ),
            ],
          ),
        ),
      ),
    );
    final note = noteCtrl.text.trim();
    noteCtrl.dispose();
    if (ok != true || picked == null || picked == a.statusId) return;

    try {
      final r = await ref.read(extrasDataSourceProvider).updateTicketStatus(widget.ticketId, picked!, note);
      if (!mounted) return;
      _toast(r.message.isNotEmpty ? r.message : (r.success ? 'Status updated' : 'Could not update'), error: !r.success);
      ref.invalidate(ticketActivityProvider(widget.ticketId));
    } catch (e) {
      if (mounted) _toast(AsyncValueView.messageOf(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(ticketActivityProvider(widget.ticketId));
    final myEmpId = ref.watch(userProfileProvider).profile?.employeeId;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: Text('Ticket ${widget.ticketNo}')),
      body: AsyncValueView<TicketActivity>(
        value: data,
        onRetry: () => ref.invalidate(ticketActivityProvider(widget.ticketId)),
        builder: (a) {
          final comments = [...a.comments]..sort((x, y) => (y.at ?? DateTime(0)).compareTo(x.at ?? DateTime(0)));
          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(ticketActivityProvider(widget.ticketId));
                    await ref.read(ticketActivityProvider(widget.ticketId).future);
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      SurfaceCard(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(a.subject, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Row(children: [
                            StatusChip(label: a.statusName.isEmpty ? 'Open' : a.statusName, color: AppColors.info),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => _changeStatus(a),
                              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                              label: const Text('Change status'),
                            ),
                          ]),
                          const Divider(height: 18),
                          _kv('Requested by', a.requester),
                          _kv('Assigned to', a.assignee.isEmpty ? 'Unassigned' : a.assignee),
                          if (a.priority.isNotEmpty) _kv('Priority', a.priority),
                          if (a.category.isNotEmpty) _kv('Category', a.category),
                        ]),
                      ),
                      if (a.approvals.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const SectionHeader('Approvals'),
                        const SizedBox(height: 6),
                        for (final p in a.approvals)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: UserAvatar(name: p.name, radius: 16),
                            title: Text(p.name),
                            trailing: Text(p.action.isEmpty ? 'Pending' : p.action, style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                      ],
                      if (a.attachments.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const SectionHeader('Attachments'),
                        const SizedBox(height: 6),
                        for (final f in a.attachments)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.attach_file_rounded, color: AppColors.primary),
                            title: Text(f.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text([if (f.uploadedBy.isNotEmpty) f.uploadedBy, formatDateTimeShort(f.at)].join(' · ')),
                            onTap: () => _openAttachment(f),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              tooltip: 'Remove',
                              onPressed: () => _removeAttachment(f),
                            ),
                          ),
                      ],
                      const SizedBox(height: 16),
                      const SectionHeader('Conversation'),
                      const SizedBox(height: 6),
                      if (comments.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text('No comments yet.', style: TextStyle(color: Colors.grey.shade600)),
                        ),
                      for (final c in comments)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Align(
                            alignment: c.empId == myEmpId ? Alignment.centerRight : Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: c.empId == myEmpId ? AppColors.primaryContainer : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFEEF1F6)),
                                ),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(c.text),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${c.empId == myEmpId ? 'You' : 'Team'} · ${formatDateTimeShort(c.at)}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                  ),
                                ]),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 8, 8),
                  child: Row(children: [
                    IconButton(
                      onPressed: _busy ? null : _attach,
                      tooltip: 'Attach a file',
                      icon: const Icon(Icons.attach_file_rounded),
                    ),
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
                      icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(k, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}
