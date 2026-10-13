import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../navigation/app_menu.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/leave_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/common/async_value_view.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/ui_helpers.dart';

/// Notifications tab: server notifications with read/unread state.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _iconFor(String type) {
    final t = type.toLowerCase();
    if (t.contains('leave')) return Icons.event_note_rounded;
    if (t.contains('regular') || t.contains('attend')) return Icons.edit_calendar_rounded;
    if (t.contains('wfh') || t.contains('home')) return Icons.home_work_rounded;
    if (t.contains('ticket')) return Icons.support_agent_rounded;
    if (t.contains('pay')) return Icons.receipt_long_rounded;
    if (t.contains('recogn') || t.contains('kudos')) return Icons.emoji_events_rounded;
    if (t.contains('todo') || t.contains('task')) return Icons.checklist_rounded;
    return Icons.notifications_rounded;
  }

  Color _colorFor(String type) {
    final t = type.toLowerCase();
    if (t.contains('leave')) return const Color(0xFF7E57C2);
    if (t.contains('regular') || t.contains('attend')) return const Color(0xFF26A69A);
    if (t.contains('wfh') || t.contains('home')) return const Color(0xFF29B6F6);
    if (t.contains('ticket')) return const Color(0xFFEF5350);
    if (t.contains('recogn') || t.contains('kudos')) return const Color(0xFFFFA000);
    return AppColors.primary;
  }

  void _reload(WidgetRef ref) {
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationsProvider).valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: const MenuButton(),
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () async {
                await ref.read(notificationDataSourceProvider).markAllRead();
                _reload(ref);
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _reload(ref);
          await ref.read(notificationsProvider.future);
        },
        child: AsyncValueView<List<AppNotification>>(
          value: data,
          onRetry: () => _reload(ref),
          builder: (list) {
            if (list.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                EmptyStateWidget(title: 'No notifications', icon: Icons.notifications_none_outlined),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final n = list[i];
                return SurfaceCard(
                  padding: const EdgeInsets.all(14),
                  onTap: () async {
                    if (!n.isRead) {
                      await ref.read(notificationDataSourceProvider).markRead(n.id);
                      _reload(ref);
                    }
                    if (context.mounted) openWebRoute(context, ref, n.link);
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconBadge(icon: _iconFor(n.type), color: _colorFor(n.type), size: 42),
                            if (!n.isRead)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  width: 11,
                                  height: 11,
                                  decoration: BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n.title,
                                style: TextStyle(fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700)),
                            if (n.message.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(n.message, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                            ],
                            const SizedBox(height: 6),
                            Text(formatDateTimeShort(n.createdDate),
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
      ),
    );
  }
}
