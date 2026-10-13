import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../data/models/ticket_model.dart';
import '../repositories/ticket_repository.dart';

/// Use case for getting tickets
class GetTicketsUseCase {
  final TicketRepository _repository;

  GetTicketsUseCase(this._repository);

  Future<Either<Failure, TicketListResponse>> call({
    required int startIndex,
    required int pageSize,
    String keyword = '',
  }) async {
    return await _repository.getTickets(
      startIndex: startIndex,
      pageSize: pageSize,
      keyword: keyword,
    );
  }
}

/// Use case for saving (add/update) ticket
class SaveTicketUseCase {
  final TicketRepository _repository;

  SaveTicketUseCase(this._repository);

  Future<Either<Failure, SaveTicketResponse>> call({
    required TicketModel ticket,
  }) async {
    return await _repository.saveTicket(ticket: ticket);
  }
}
