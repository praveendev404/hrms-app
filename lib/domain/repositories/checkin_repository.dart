import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../data/models/checkin_model.dart';

/// Repository interface for check-in operations
abstract class CheckInRepository {
  Future<Either<Failure, bool>> postCheckIn(CheckInRequest request);
  Future<Either<Failure, CheckInResponse?>> getLatestCheckIn();
}
