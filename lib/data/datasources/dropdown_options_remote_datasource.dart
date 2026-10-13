import '../../core/network/api_client.dart';
import '../models/dropdown_option_model.dart';

/// Remote datasource for fetching dropdown options
abstract class DropdownOptionsRemoteDataSource {
  Future<List<DropdownOptionModel>> getTicketCategories();
  Future<List<DropdownOptionModel>> getLabels();
  Future<List<DropdownOptionModel>> getPriorities();
  Future<List<DropdownOptionModel>> getTicketStatuses();
}

class DropdownOptionsRemoteDataSourceImpl implements DropdownOptionsRemoteDataSource {
  final ApiClient _apiClient;

  DropdownOptionsRemoteDataSourceImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<List<DropdownOptionModel>> getTicketCategories() async {
    try {
      final response = await _apiClient.get(
        '/api/v1/admin/GetParentOptions/ticketcatgories',
      );
      
      if (response.data is List) {
        return (response.data as List)
            .map((item) => DropdownOptionModel.fromJson(item))
            .toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<DropdownOptionModel>> getLabels() async {
    try {
      final response = await _apiClient.get(
        '/api/v1/admin/GetParentOptions/labels',
      );
      
      if (response.data is List) {
        return (response.data as List)
            .map((item) => DropdownOptionModel.fromJson(item))
            .toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<DropdownOptionModel>> getPriorities() async {
    try {
      final response = await _apiClient.get(
        '/api/v1/admin/GetParentOptions/priorities',
      );
      
      if (response.data is List) {
        return (response.data as List)
            .map((item) => DropdownOptionModel.fromJson(item))
            .toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<DropdownOptionModel>> getTicketStatuses() async {
    try {
      final response = await _apiClient.get(
        '/api/v1/admin/GetParentOptions/ticketstatus',
      );
      
      if (response.data is List) {
        return (response.data as List)
            .map((item) => DropdownOptionModel.fromJson(item))
            .toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }
}
