import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../data/models/checkin_model.dart';
import '../repositories/checkin_repository.dart';

/// Use case for posting check-in
class PostCheckInUseCase {
  final CheckInRepository repository;

  PostCheckInUseCase(this.repository);

  Future<Either<Failure, bool>> call(CheckInRequest request) {
    return repository.postCheckIn(request);
  }
}

/// Use case for getting latest check-in
class GetLatestCheckInUseCase {
  final CheckInRepository repository;

  GetLatestCheckInUseCase(this.repository);

  Future<Either<Failure, CheckInResponse?>> call() {
    return repository.getLatestCheckIn();
  }
}
