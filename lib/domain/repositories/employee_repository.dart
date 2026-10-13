import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../data/models/employee_model.dart';

/// Employee repository interface
abstract class EmployeeRepository {
  Future<Either<Failure, EmployeeListResponse>> getEmployees({
    required int startIndex,
    required int pageSize,
    String keyword = '',
  });
}
