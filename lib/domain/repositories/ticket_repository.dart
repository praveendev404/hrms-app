import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../data/models/ticket_model.dart';

/// Ticket repository interface
abstract class TicketRepository {
  Future<Either<Failure, TicketListResponse>> getTickets({
    required int startIndex,
    required int pageSize,
    String keyword = '',
  });

  Future<Either<Failure, SaveTicketResponse>> saveTicket({
    required TicketModel ticket,
  });
}
