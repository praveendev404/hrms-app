import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/phone_calendar.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/common/async_value_view.dart';
import '../../widgets/common/empty_state_widget.dart';

/// Upcoming holidays for the user's organisation / business unit.
class HolidaysScreen extends ConsumerWidget {
  const HolidaysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Holidays')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(holidaysProvider.future),
        child: AsyncValueView(
          value: ref.watch(holidaysProvider),
          onRetry: () => ref.invalidate(holidaysProvider),
          builder: (list) {
            if (list.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                EmptyStateWidget(title: 'No upcoming holidays', icon: Icons.celebration_outlined),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final h = list[i];
                final d = h.date;
                return Card(
                  elevation: 0,
                  child: ListTile(
                    leading: Container(
                      width: 48,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(d == null ? '' : DateFormat('d').format(d),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.primary)),
                          Text(d == null ? '' : DateFormat('MMM').format(d), style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                    title: Text(h.name),
                    subtitle: Text(d == null ? '' : DateFormat('EEEE').format(d)),
                    trailing: d == null
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.event_available_outlined),
                            tooltip: 'Add to phone calendar',
                            onPressed: () => addAllDayToPhoneCalendar(title: h.name, from: d, description: 'Company holiday'),
                          ),
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
