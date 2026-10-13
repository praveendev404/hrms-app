import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/extras_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/common/async_value_view.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/ui_helpers.dart';

/// Assets currently issued to me.
class MyAssetsScreen extends ConsumerWidget {
  const MyAssetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('My assets')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myAssetsProvider);
          await ref.read(myAssetsProvider.future);
        },
        child: AsyncValueView<List<AssetItem>>(
          value: ref.watch(myAssetsProvider),
          onRetry: () => ref.invalidate(myAssetsProvider),
          builder: (list) {
            if (list.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 100),
                EmptyStateWidget(title: 'No assets issued to you', icon: Icons.laptop_mac_outlined),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final a = list[i];
                return SurfaceCard(
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.devices_other_outlined, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.typeName.isEmpty ? a.code : a.typeName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(a.code, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          if ((a.description ?? '').isNotEmpty)
                            Text(a.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                          if (a.issueDate != null)
                            Text('Issued ${formatYmd(a.issueDate, withYear: true)}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    if (a.statusName.isNotEmpty) StatusChip(label: a.statusName, color: AppColors.info),
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
