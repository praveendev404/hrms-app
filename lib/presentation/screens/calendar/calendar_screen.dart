import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/dashboard_models.dart';
import '../../../data/models/leave_models.dart';
import '../../../data/models/work_models.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/common/ui_helpers.dart';

final _ymd = DateFormat('yyyy-MM-dd');

/// One month at a glance: week-offs, holidays, my leave and my attendance.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selected = DateTime.now();

  String get _key => DateFormat('yyyy-MM').format(_month);

  void _shift(int d) => setState(() {
        _month = DateTime(_month.year, _month.month + d);
        _selected = null;
      });

  @override
  Widget build(BuildContext context) {
    final attendance = ref.watch(myAttendanceProvider(_key)).valueOrNull ?? const <AttendanceDay>[];
    final leaves = ref.watch(myLeaveRequestsProvider).valueOrNull ?? const <LeaveRequest>[];
    final holidays = ref.watch(holidaysProvider).valueOrNull ?? const <HolidayItem>[];
    final weekOffs = ref.watch(weekOffsProvider).valueOrNull ?? const <WeekOffRule>[];

    final attByDate = {for (final a in attendance) a.date: a};
    final holByDate = {for (final h in holidays) if (h.date != null) _ymd.format(h.date!): h};

    LeaveRequest? leaveOn(DateTime d) {
      final k = _ymd.format(d);
      for (final l in leaves) {
        if (l.statusId == LeaveStatus.cancelled || l.statusId == LeaveStatus.rejected) continue;
        if (l.fromDate.compareTo(k) <= 0 && l.toDate.compareTo(k) >= 0) return l;
      }
      return null;
    }

    bool isOff(DateTime d) => weekOffs.any((w) => w.isOff(d));

    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = first.weekday - 1; // Monday-first grid
    final cells = lead + daysInMonth;
    final rows = (cells / 7).ceil();

    Widget cell(DateTime? d) {
      if (d == null) return const SizedBox.shrink();
      final key = _ymd.format(d);
      final att = attByDate[key];
      final hol = holByDate[key];
      final lv = leaveOn(d);
      final off = isOff(d);
      final today = _ymd.format(DateTime.now()) == key;
      final selected = _selected != null && _ymd.format(_selected!) == key;

      final dots = <Color>[
        if (hol != null) AppColors.warning,
        if (lv != null) (lv.statusId == LeaveStatus.approved ? AppColors.primary : const Color(0xFFB39DDB)),
        if (att != null && att.hasPunches) (att.isMissingPunchOut ? AppColors.error : (att.isLate ? const Color(0xFFFFB74D) : AppColors.success)),
        if (att != null && att.isWfh) AppColors.info,
      ];

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _selected = d),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryContainer : (off ? const Color(0xFFF1F5F9) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: today ? AppColors.primary : const Color(0xFFEEF1F6), width: today ? 2 : 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${d.day}',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: off ? Colors.grey : (hol != null ? AppColors.warning : AppColors.textPrimaryLight))),
              const SizedBox(height: 3),
              SizedBox(
                height: 7,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (final c in dots.take(3))
                    Container(width: 6, height: 6, margin: const EdgeInsets.symmetric(horizontal: 1), decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                ]),
              ),
            ],
          ),
        ),
      );
    }

    final detailDay = _selected;
    final dAtt = detailDay == null ? null : attByDate[_ymd.format(detailDay)];
    final dHol = detailDay == null ? null : holByDate[_ymd.format(detailDay)];
    final dLeave = detailDay == null ? null : leaveOn(detailDay);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Calendar')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shift(-1)),
            Text(DateFormat('MMMM yyyy').format(_month), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _shift(1)),
          ]),
          Row(children: [
            for (final w in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(child: Center(child: Text(w, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)))),
          ]),
          const SizedBox(height: 4),
          for (var r = 0; r < rows; r++)
            SizedBox(
              height: 52,
              child: Row(children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: Builder(builder: (_) {
                      final n = r * 7 + c - lead + 1;
                      return cell(n < 1 || n > daysInMonth ? null : DateTime(_month.year, _month.month, n));
                    }),
                  ),
              ]),
            ),
          const SizedBox(height: 10),
          Wrap(spacing: 14, runSpacing: 6, children: const [
            _Key('Holiday', AppColors.warning),
            _Key('Leave', AppColors.primary),
            _Key('Present', AppColors.success),
            _Key('Late', Color(0xFFFFB74D)),
            _Key('Missing punch-out', AppColors.error),
            _Key('WFH', AppColors.info),
          ]),
          const SizedBox(height: 14),
          if (detailDay != null)
            SurfaceCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(DateFormat('EEEE, d MMMM').format(detailDay), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (isOff(detailDay)) const _Line(Icons.weekend_outlined, 'Weekly off'),
                if (dHol != null) _Line(Icons.celebration_outlined, 'Holiday: ${dHol.name}'),
                if (dLeave != null)
                  _Line(Icons.event_note_outlined,
                      '${dLeave.leaveTypeName} (${dLeave.statusName.isEmpty ? 'requested' : dLeave.statusName}) · ${formatDateRange(dLeave.fromDate, dLeave.toDate)}'),
                if (dAtt != null && dAtt.hasPunches)
                  _Line(Icons.access_time,
                      'In ${dAtt.firstIn ?? '--'} · Out ${dAtt.lastOut ?? '--'} · ${dAtt.totalHours.toStringAsFixed(1)} h'
                      '${dAtt.isLate ? ' · Late ${dAtt.lateByMinutes}m' : ''}'),
                if (dAtt != null && dAtt.isWfh) _Line(Icons.home_work_outlined, 'Work from home'),
                if (!isOff(detailDay) && dHol == null && dLeave == null && (dAtt == null || (!dAtt.hasPunches && !dAtt.isWfh)))
                  Text('Nothing recorded for this day.', style: TextStyle(color: Colors.grey.shade600)),
              ]),
            ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  final String label;
  final Color color;
  const _Key(this.label, this.color);

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
      ]);
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Line(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ]),
      );
}
