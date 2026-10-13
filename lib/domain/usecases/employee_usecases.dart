import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../data/models/employee_model.dart';
import '../repositories/employee_repository.dart';

/// Use case for getting employees
class GetEmployeesUseCase {
  final EmployeeRepository _repository;

  GetEmployeesUseCase(this._repository);

  Future<Either<Failure, EmployeeListResponse>> call({
    required int startIndex,
    required int pageSize,
    String keyword = '',
  }) {
    return _repository.getEmployees(
      startIndex: startIndex,
      pageSize: pageSize,
      keyword: keyword,
    );
  }
}
