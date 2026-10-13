import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/dashboard_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/common/async_value_view.dart';
import '../../widgets/common/chart_bars.dart';
import '../../widgets/common/ui_helpers.dart';

const _charts = <({String type, String title})>[
  (type: 'headcounttrend', title: 'Headcount trend'),
  (type: 'attrition', title: 'Attrition'),
  (type: 'hiringfunnel', title: 'Hiring funnel'),
  (type: 'leavebydept', title: 'Leave by department'),
  (type: 'leaveutilization', title: 'Leave utilisation'),
  (type: 'departentcountchart', title: 'Headcount by department'),
  (type: 'gender', title: 'Gender mix'),
  (type: 'age', title: 'Age groups'),
  (type: 'attendanceoverview', title: 'Attendance overview'),
  (type: 'latearrivals', title: 'Late arrivals'),
];

/// Organisation-wide HR numbers for org admins and HR. Every figure is gated by the server:
/// anything the role may not see shows "You do not have access".
class HrAnalyticsScreen extends ConsumerStatefulWidget {
  const HrAnalyticsScreen({super.key});

  @override
  ConsumerState<HrAnalyticsScreen> createState() => _HrAnalyticsScreenState();
}

class _HrAnalyticsScreenState extends ConsumerState<HrAnalyticsScreen> {
  int? _deptId;
  int? _year;

  String _key(String type) => '$type|${_deptId ?? 0}|${_year ?? 0}';

  Future<void> _refresh() async {
    ref.invalidate(analyticsSummaryProvider(_deptId));
    for (final c in _charts) {
      ref.invalidate(analyticsChartProvider(_key(c.type)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final depts = ref.watch(departmentOptionsProvider).valueOrNull ?? const [];
    final now = DateTime.now().year;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('HR analytics')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<int?>(
              value: depts.any((d) => d.value == _deptId) ? _deptId : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Department'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('All departments')),
                for (final d in depts) DropdownMenuItem<int?>(value: d.value, child: Text(d.label)),
              ],
              onChanged: (v) => setState(() => _deptId = v),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              ChoiceChip(label: const Text('All years'), selected: _year == null, onSelected: (_) => setState(() => _year = null)),
              for (final y in [now, now - 1, now - 2])
                ChoiceChip(label: Text('$y'), selected: _year == y, onSelected: (_) => setState(() => _year = y)),
            ]),
            const SizedBox(height: 16),
            AsyncValueView<AnalyticsSummary>(
              compact: true,
              value: ref.watch(analyticsSummaryProvider(_deptId)),
              onRetry: () => ref.invalidate(analyticsSummaryProvider(_deptId)),
              builder: (s) => GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.9,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  _Kpi('Employees', '${s.totalEmployees}', Icons.people_alt_outlined, const Color(0xFF5C6BC0)),
                  _Kpi('Joined this month', '${s.newJoinees}', Icons.person_add_alt_outlined, const Color(0xFF26A69A)),
                  _Kpi('Exits this month', '${s.exits}', Icons.logout_rounded, const Color(0xFFEF5350)),
                  _Kpi('Attrition', '${s.attritionPercent.toStringAsFixed(1)}%', Icons.trending_down_rounded, const Color(0xFFFF9800)),
                  _Kpi('Open positions', '${s.openPositions}', Icons.work_outline_rounded, const Color(0xFF42A5F5)),
                  _Kpi('Candidates', '${s.candidates}', Icons.badge_outlined, const Color(0xFF7E57C2)),
                  _Kpi('Leave days', '${s.leaveDays}', Icons.event_note_outlined, const Color(0xFF66BB6A)),
                  _Kpi('Pending leave', '${s.pendingLeave}', Icons.pending_actions_outlined, AppColors.warning),
                ],
              ),
            ),
            const SizedBox(height: 20),
            for (final c in _charts)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      AsyncValueView<List<ChartPoint>>(
                        compact: true,
                        value: ref.watch(analyticsChartProvider(_key(c.type))),
                        onRetry: () => ref.invalidate(analyticsChartProvider(_key(c.type))),
                        builder: (pts) => ChartBars(points: pts),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _Kpi(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        IconBadge(icon: icon, color: color, size: 38),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ]),
    );
  }
}
