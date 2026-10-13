import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../data/models/attendance_model.dart';
import '../repositories/attendance_repository.dart';

/// Use case for fetching attendance data
class GetAttendanceUseCase {
  final AttendanceRepository _repository;

  GetAttendanceUseCase(this._repository);

  Future<Either<Failure, AttendanceResponse>> call(
      AttendanceRequest request) async {
    return await _repository.getAllOrgAttendance(request);
  }
}
