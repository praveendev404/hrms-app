import 'package:dartz/dartz.dart';
import '../../core/errors/exceptions.dart';
import '../../core/errors/failures.dart';
import '../../data/datasources/ticket_remote_datasource.dart';
import '../../data/models/ticket_model.dart';
import '../../domain/repositories/ticket_repository.dart';

/// Implementation of ticket repository
class TicketRepositoryImpl implements TicketRepository {
  final TicketRemoteDataSource _remoteDataSource;

  TicketRepositoryImpl({required TicketRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource;

  @override
  Future<Either<Failure, TicketListResponse>> getTickets({
    required int startIndex,
    required int pageSize,
    String keyword = '',
  }) async {
    try {
      final request = TicketRequest(
        startIndex: startIndex,
        pageSize: pageSize,
        keyword: keyword,
      );
      final response = await _remoteDataSource.getTickets(request);
      return Right(response);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, SaveTicketResponse>> saveTicket({
    required TicketModel ticket,
  }) async {
    try {
      final request = SaveTicketRequest(model: ticket);
      final response = await _remoteDataSource.saveTicket(request);
      return Right(response);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}
