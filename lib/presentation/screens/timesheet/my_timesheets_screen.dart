import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/work_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/common/async_value_view.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/ui_helpers.dart';

/// My timesheets (read-only on mobile: week, status and hours).
/// Entering and submitting time is done on the web for now.
class MyTimesheetsScreen extends ConsumerWidget {
  const MyTimesheetsScreen({super.key});

  Color _color(int s) {
    switch (s) {
      case TimesheetStatus.approved:
        return AppColors.success;
      case TimesheetStatus.rejected:
        return AppColors.error;
      case TimesheetStatus.submitted:
        return AppColors.info;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('My timesheets')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myTimesheetsProvider);
          await ref.read(myTimesheetsProvider.future);
        },
        child: AsyncValueView<List<TimesheetItem>>(
          value: ref.watch(myTimesheetsProvider),
          onRetry: () => ref.invalidate(myTimesheetsProvider),
          builder: (list) {
            if (list.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 100),
                EmptyStateWidget(title: 'No timesheets yet', icon: Icons.schedule_outlined),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final t = list[i];
                return SurfaceCard(
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(formatDateRange(t.fromDate, t.toDate), style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('${t.totalHours} h total  ·  ${t.billableHours} h billable',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          if ((t.managerName ?? '').isNotEmpty)
                            Text('Manager: ${t.managerName}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                    StatusChip(label: t.statusName, color: _color(t.statusId)),
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
