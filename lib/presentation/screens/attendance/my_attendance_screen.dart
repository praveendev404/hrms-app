import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/work_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/common/async_value_view.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../widgets/common/ui_helpers.dart';
import '../requests/requests_screen.dart';

/// My attendance for a month: punches, hours, late marks, WFH and regularization status.
class MyAttendanceScreen extends ConsumerStatefulWidget {
  const MyAttendanceScreen({super.key});

  @override
  ConsumerState<MyAttendanceScreen> createState() => _MyAttendanceScreenState();
}

class _MyAttendanceScreenState extends ConsumerState<MyAttendanceScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String? _selectedDate; // yyyy-MM-dd of the tapped bar

  String get _key => DateFormat('yyyy-MM').format(_month);

  bool get _isCurrentMonth {
    final n = DateTime.now();
    return _month.year == n.year && _month.month == n.month;
  }

  void _shift(int delta) => setState(() {
        _month = DateTime(_month.year, _month.month + delta);
        _selectedDate = null;
      });

  Future<void> _regularize(AttendanceDay d) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => RegularizeForm(initialDate: DateTime.tryParse(d.date)),
    );
    if (ok == true) ref.invalidate(myAttendanceProvider(_key));
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(myAttendanceProvider(_key));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('My attendance')),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shift(-1)),
                Text(DateFormat('MMMM yyyy').format(_month),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _isCurrentMonth ? null : () => _shift(1),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(myAttendanceProvider(_key));
                await ref.read(myAttendanceProvider(_key).future);
              },
              child: AsyncValueView<List<AttendanceDay>>(
                value: data,
                onRetry: () => ref.invalidate(myAttendanceProvider(_key)),
                builder: (days) {
                  if (days.isEmpty) {
                    return ListView(children: const [
                      SizedBox(height: 100),
                      EmptyStateWidget(title: 'No days to show', icon: Icons.event_busy_outlined),
                    ]);
                  }
                  final present = days.where((d) => d.hasPunches || d.isWfh).length;
                  final late = days.where((d) => d.isLate).length;
                  final hours = days.fold<double>(0, (a, d) => a + d.totalHours);
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(children: [
                        _Stat('Days present', '$present', AppColors.success),
                        const SizedBox(width: 10),
                        _Stat('Late', '$late', AppColors.warning),
                        const SizedBox(width: 10),
                        _Stat('Hours', hours.toStringAsFixed(1), AppColors.primary),
                      ]),
                      const SizedBox(height: 16),
                      _HoursChart(
                        key: ValueKey(_key),
                        days: days,
                        selectedDate: _selectedDate,
                        onSelect: (d) => setState(() => _selectedDate = d),
                      ),
                      const SizedBox(height: 16),
                      if (_selectedDate != null) ...[
                        for (final d in days.where((x) => x.date == _selectedDate))
                          _DayCard(day: d, onRegularize: () => _regularize(d)),
                        const SizedBox(height: 16),
                      ],
                      Text('All days', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      for (final d in days)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _DayCard(day: d, onRegularize: () => _regularize(d)),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SurfaceCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final AttendanceDay day;
  final VoidCallback onRegularize;
  const _DayCard({required this.day, required this.onRegularize});

  @override
  Widget build(BuildContext context) {
    final d = DateTime.tryParse(day.date);
    final weekend = d != null && (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday);
    final needsFix = day.isMissingPunchOut && !day.isRegularize;

    return SurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: weekend ? Colors.grey.shade200 : AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(children: [
              Text(d == null ? '' : DateFormat('d').format(d),
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: weekend ? Colors.grey : AppColors.primary)),
              Text(d == null ? '' : DateFormat('EEE').format(d), style: const TextStyle(fontSize: 11)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (day.hasPunches)
                  Text('${day.firstIn ?? '--'} – ${day.lastOut ?? '--'}   ·   ${day.totalHours.toStringAsFixed(1)} h',
                      style: const TextStyle(fontWeight: FontWeight.w600))
                else
                  Text(weekend ? 'Weekend' : 'No punches', style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  if (day.isLate)
                    StatusChip(
                      label: day.lateByMinutes > 0 ? 'Late ${day.lateByMinutes}m' : 'Late',
                      color: AppColors.warning,
                    ),
                  if (day.isMissingPunchOut) const StatusChip(label: 'Missing punch-out', color: AppColors.error),
                  if (day.isWfh) const StatusChip(label: 'WFH', color: AppColors.info),
                  if (day.isRegularize)
                    StatusChip(
                      label: 'Regularize: ${day.regularizeStatus ?? 'requested'}',
                      color: AppColors.primary,
                    ),
                ]),
                if (needsFix)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(onPressed: onRegularize, child: const Text('Request regularization')),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Daily hours as bars, oldest -> newest, scrolling horizontally. The view opens on the
/// most recent days. Colour says what kind of day it was; tap a bar to see that day.
class _HoursChart extends StatefulWidget {
  final List<AttendanceDay> days; // newest first, as the API returns them
  final String? selectedDate;
  final ValueChanged<String> onSelect;

  const _HoursChart({super.key, required this.days, required this.selectedDate, required this.onSelect});

  @override
  State<_HoursChart> createState() => _HoursChartState();
}

class _HoursChartState extends State<_HoursChart> {
  static const double _barWidth = 28;
  static const double _slot = 46;
  static const double _plotHeight = 130;
  // Reference line only; the real shift length is tenant/shift specific.
  static const double _referenceHours = 8;

  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Open on the newest days (right edge).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Color _color(AttendanceDay d) {
    if (d.isMissingPunchOut) return AppColors.error;
    if (d.isLate) return AppColors.warning;
    if (d.isWfh) return AppColors.info;
    if (d.hasPunches) return AppColors.success;
    return Colors.grey.shade300;
  }

  @override
  Widget build(BuildContext context) {
    final ordered = [...widget.days]..sort((a, b) => a.date.compareTo(b.date));
    final maxHours = ordered.fold<double>(_referenceHours, (m, d) => d.totalHours > m ? d.totalHours : m);
    final scale = _plotHeight / (maxHours + 1);

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Daily hours', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('Swipe to scroll', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: _plotHeight + 56,
            child: Stack(
              children: [
                // 8h reference line (behind the scrolling bars).
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 36 + _referenceHours * scale,
                  child: Row(children: [
                    Text('${_referenceHours.toInt()}h', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    const SizedBox(width: 4),
                    Expanded(child: Divider(height: 1, color: Colors.grey.shade300)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 22),
                  child: ListView.builder(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    itemCount: ordered.length,
                    itemBuilder: (_, i) {
                      final d = ordered[i];
                      final date = DateTime.tryParse(d.date);
                      final selected = d.date == widget.selectedDate;
                      final weekend = date != null && (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday);
                      final barH = d.totalHours <= 0 ? 3.0 : (d.totalHours * scale).clamp(3.0, _plotHeight);
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => widget.onSelect(d.date),
                        child: SizedBox(
                          width: _slot,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(d.totalHours > 0 ? d.totalHours.toStringAsFixed(1) : '',
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
                              const SizedBox(height: 2),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: _barWidth,
                                height: barH,
                                decoration: BoxDecoration(
                                  color: _color(d),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                  border: selected ? Border.all(color: AppColors.primaryDark, width: 2) : null,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                width: _barWidth + 6,
                                decoration: BoxDecoration(
                                  color: selected ? AppColors.primaryContainer : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Column(children: [
                                  Text(date == null ? '' : DateFormat('d').format(date),
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: weekend ? Colors.grey : Colors.black87)),
                                  Text(date == null ? '' : DateFormat('E').format(date).substring(0, 1),
                                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                ]),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Wrap(spacing: 12, runSpacing: 4, children: const [
            _Legend('On time', AppColors.success),
            _Legend('Late', AppColors.warning),
            _Legend('Missing punch-out', AppColors.error),
            _Legend('WFH', AppColors.info),
          ]),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final String label;
  final Color color;
  const _Legend(this.label, this.color);

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade700)),
      ]);
}
