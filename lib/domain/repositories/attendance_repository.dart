import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../data/models/attendance_model.dart';

/// Attendance repository interface
abstract class AttendanceRepository {
  Future<Either<Failure, AttendanceResponse>> getAllOrgAttendance(
      AttendanceRequest request);
}
