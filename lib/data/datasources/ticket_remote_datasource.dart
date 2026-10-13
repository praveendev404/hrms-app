import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../models/ticket_model.dart';

/// Remote data source for ticket operations
abstract class TicketRemoteDataSource {
  Future<TicketListResponse> getTickets(TicketRequest request);
  Future<SaveTicketResponse> saveTicket(SaveTicketRequest request);
}

/// Implementation of ticket remote data source
class TicketRemoteDataSourceImpl implements TicketRemoteDataSource {
  final ApiClient _apiClient;

  TicketRemoteDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<TicketListResponse> getTickets(TicketRequest request) async {
    final response = await _apiClient.post(
      ApiEndpoints.ticketGetAll,
      data: request.toJson(),
    );

    return TicketListResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<SaveTicketResponse> saveTicket(SaveTicketRequest request) async {
    // New tickets are POSTed, edits PUT (the same split the web makes).
    final isEdit = request.model.id != 0;
    final response = isEdit
        ? await _apiClient.put(ApiEndpoints.ticket, data: request.toJson())
        : await _apiClient.post(ApiEndpoints.ticket, data: request.toJson());

    return SaveTicketResponse.fromJson(response.data as Map<String, dynamic>);
  }
}
