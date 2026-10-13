import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/dashboard_models.dart';

/// Horizontal bars for a list of labelled values (shared by dashboard and analytics).
class ChartBars extends StatelessWidget {
  final List<ChartPoint> points;
  final int maxItems;
  const ChartBars({super.key, required this.points, this.maxItems = 12});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('No data for this period.', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
      );
    }
    final shown = points.take(maxItems).toList();
    final max = shown.map((p) => p.value).fold<double>(0, (a, b) => b > a ? b : a);
    return Column(
      children: [
        for (final p in shown)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(p.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: max <= 0 ? 0 : p.value / max,
                      minHeight: 8,
                      backgroundColor: AppColors.primaryContainer,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: Text(
                    p.value == p.value.roundToDouble() ? p.value.toInt().toString() : p.value.toStringAsFixed(1),
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
