import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/request_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/common/async_value_view.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/ui_helpers.dart';

/// My payslips by year; tap to download and open the PDF.
class PayslipsScreen extends ConsumerStatefulWidget {
  const PayslipsScreen({super.key});

  @override
  ConsumerState<PayslipsScreen> createState() => _PayslipsScreenState();
}

class _PayslipsScreenState extends ConsumerState<PayslipsScreen> {
  late int _year = DateTime.now().year;
  int? _downloadingId;

  Future<void> _open(PayslipItem p) async {
    setState(() => _downloadingId = p.id);
    try {
      final path = await ref.read(requestDataSourceProvider).downloadPayslip(p);
      final res = await OpenFilex.open(path);
      if (res.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No app available to open PDF files (${res.message}).'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AsyncValueView.messageOf(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().year;
    final data = ref.watch(payslipsProvider(_year));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Payslips'),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _year,
              items: [for (var y = now; y >= now - 5; y--) DropdownMenuItem(value: y, child: Text('$y'))],
              onChanged: (v) => setState(() => _year = v ?? _year),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(payslipsProvider(_year));
          await ref.read(payslipsProvider(_year).future);
        },
        child: AsyncValueView<List<PayslipItem>>(
          value: data,
          onRetry: () => ref.invalidate(payslipsProvider(_year)),
          builder: (list) {
            if (list.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 100),
                EmptyStateWidget(title: 'No payslips for $_year', icon: Icons.receipt_long_outlined),
              ]);
            }
            final sorted = [...list]..sort((a, b) => b.toDate.compareTo(a.toDate));
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final p = sorted[i];
                final month = DateTime.tryParse(p.toDate);
                final busy = _downloadingId == p.id;
                return SurfaceCard(
                  onTap: busy ? null : () => _open(p),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(month == null ? formatDateRange(p.fromDate, p.toDate) : DateFormat('MMMM yyyy').format(month),
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(formatDateRange(p.fromDate, p.toDate),
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(p.filePath == null ? Icons.hourglass_empty : Icons.download_outlined, color: Colors.grey),
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
