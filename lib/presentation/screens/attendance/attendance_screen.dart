import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/attendance_model.dart';
import '../../providers/attendance_provider.dart';
import '../../widgets/common/loading_widget.dart';

/// Attendance screen
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendanceProvider.notifier).fetchAttendance();
    });
  }

  @override
  Widget build(BuildContext context) {
    final attendanceState = ref.watch(attendanceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'Attendance',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildHeader(attendanceState),
          _buildLegend(),
          Expanded(
            child: attendanceState.isLoading
                ? const LoadingWidget()
                : attendanceState.errorMessage != null
                    ? _buildError(attendanceState.errorMessage!)
                    : attendanceState.data != null
                        ? _buildAttendanceTable(attendanceState.data!, attendanceState)
                        : const Center(child: Text('No data available')),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AttendanceState state) {
    final data = state.data;
    
    // Use selectedDate if available, otherwise use selectedMonth
    final dateStr = state.selectedDate ?? DateFormat('yyyy-MM-dd').format(state.selectedMonth);
    
    DateTime selectedDateTime;
    try {
      selectedDateTime = DateTime.parse(dateStr);
    } catch (e) {
      selectedDateTime = state.selectedMonth;
    }
    
    final displayDate = DateFormat('dd MMM yyyy').format(selectedDateTime);
    
    // Get today's counts
    final counts = data?.getTodayCounts(dateStr) ?? {'present': 0, 'absent': 0, 'total': 0};

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Counts
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _buildCountBadge(
                  'Absent',
                  counts['absent'] ?? 0,
                  AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCountBadge(
                  'Present',
                  counts['present'] ?? 0,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCountBadge(
                  'Total',
                  counts['total'] ?? 0,
                  Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Month navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: TextButton(
                  onPressed: () => ref.read(attendanceProvider.notifier).previousMonth(),
                  child: const Text('Previous', overflow: TextOverflow.ellipsis),
                ),
              ),
              Flexible(
                flex: 2,
                child: TextButton(
                  onPressed: () => ref.read(attendanceProvider.notifier).currentMonth(),
                  child: Text(
                    displayDate,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Flexible(
                child: TextButton(
                  onPressed: () => ref.read(attendanceProvider.notifier).nextMonth(),
                  child: const Text('Next', overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCountBadge(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text(
              'Note:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            _buildLegendItem(Icons.calendar_today, 'Holiday'),
            _buildLegendItem(Icons.cancel, 'Comp Off'),
            _buildLegendItem(Icons.check_circle, 'Present'),
            _buildLegendItem(Icons.star, 'Half Day'),
            _buildLegendItem(Icons.cancel, 'Absent', color: Colors.red),
            _buildLegendItem(Icons.time_to_leave, 'On Leave', color: Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, String label, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color ?? Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(attendanceProvider.notifier).fetchAttendance(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceTable(AttendanceResponse data, AttendanceState state) {
    if (data.employees.isEmpty) {
      return const Center(child: Text('No employees found'));
    }

    // Get dates from first employee (all have same dates)
    final dates = data.employees.first.logsByDate;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(
              AppColors.primary.withOpacity(0.1),
            ),
            border: TableBorder.all(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            columns: [
              const DataColumn(
                label: Text(
                  'Employee Name',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              ...dates.map((day) => DataColumn(
                    label: InkWell(
                      onTap: () {
                        ref.read(attendanceProvider.notifier).selectDate(day.date);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: state.selectedDate == day.date
                              ? AppColors.primary.withOpacity(0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              day.date,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: state.selectedDate == day.date
                                    ? AppColors.primary
                                    : const Color(0xFF1A1D1F),
                              ),
                            ),
                            Text(
                              day.weekday,
                              style: TextStyle(
                                fontSize: 10,
                                color: state.selectedDate == day.date
                                    ? AppColors.primary
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )),
            ],
            rows: data.employees.map((employee) {
              return DataRow(
                cells: [
                  DataCell(
                    SizedBox(
                      width: 150,
                      child: Text(
                        employee.employeeName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  ...employee.logsByDate.map((day) {
                    return DataCell(
                      Center(
                        child: _buildStatusIcon(day),
                      ),
                    );
                  }),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(DailyAttendance day) {
    if (day.isHoliday) {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.calendar_today,
          size: 16,
          color: Colors.grey.shade600,
        ),
      );
    }

    if (day.leaveInfo != null) {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.time_to_leave,
          size: 16,
          color: Colors.orange,
        ),
      );
    }

    if (day.compOffInfo != null) {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.blue.shade100,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.cancel,
          size: 16,
          color: Colors.blue,
        ),
      );
    }

    if (day.logs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.cancel,
          size: 16,
          color: Colors.red,
        ),
      );
    }

    // Present
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.check_circle,
        size: 16,
        color: Colors.green,
      ),
    );
  }
}
