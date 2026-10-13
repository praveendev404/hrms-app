import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/work_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../widgets/common/async_value_view.dart';
import '../../widgets/common/contact_actions.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/ui_helpers.dart';

/// A person in context: their manager above, direct reports below. Tap anyone to move there.
/// Pass no [employeeId] to start from yourself.
class OrgChartScreen extends ConsumerWidget {
  final int? employeeId;
  const OrgChartScreen({super.key, this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = employeeId ?? ref.watch(userProfileProvider).profile?.employeeId;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Org chart')),
      body: id == null
          ? const Center(child: Text('Your account is not linked to an employee record.'))
          : AsyncValueView<OrgNode?>(
              value: ref.watch(orgChartProvider(id)),
              onRetry: () => ref.invalidate(orgChartProvider(id)),
              builder: (root) {
                if (root == null) {
                  return const EmptyStateWidget(title: 'No reporting line found', icon: Icons.account_tree_outlined);
                }
                final me = root.find(id) ?? root;
                final manager = root.id != me.id ? root : null;
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (manager != null) ...[
                      const SectionHeader('Reports to'),
                      const SizedBox(height: 6),
                      _PersonCard(node: manager, onTap: () => _go(context, manager.id)),
                      const _Connector(),
                    ],
                    _PersonCard(node: me, highlighted: true),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: ContactBar(mobile: me.mobile, email: me.email),
                    ),
                    const SizedBox(height: 16),
                    SectionHeader(me.children.isEmpty ? 'No direct reports' : 'Direct reports (${me.children.length})'),
                    const SizedBox(height: 6),
                    for (final c in me.children)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PersonCard(node: c, onTap: () => _go(context, c.id)),
                      ),
                  ],
                );
              },
            ),
    );
  }

  void _go(BuildContext context, int id) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => OrgChartScreen(employeeId: id)));
}

class _Connector extends StatelessWidget {
  const _Connector();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(width: 2, height: 18, margin: const EdgeInsets.symmetric(vertical: 2), color: AppColors.dividerLight),
      );
}

class _PersonCard extends StatelessWidget {
  final OrgNode node;
  final bool highlighted;
  final VoidCallback? onTap;
  const _PersonCard({required this.node, this.highlighted = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: onTap,
      child: Row(children: [
        UserAvatar(name: node.name, radius: highlighted ? 28 : 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(node.name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: highlighted ? 17 : 15)),
            Text([node.designation, node.department].where((e) => e.isNotEmpty).join(' · '),
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
          ]),
        ),
        if (onTap != null) const Icon(Icons.chevron_right, color: Colors.grey),
      ]),
    );
  }
}
