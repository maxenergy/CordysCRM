import 'package:dio/dio.dart';
import '../../core/network/dio_client.dart';
import 'sync_api_client.dart';

/// Dio implementation of SyncApiClient
///
/// Bridges the gap between SyncService and DioClient
class DioSyncApiClient implements SyncApiClient {
  final DioClient _dioClient;

  DioSyncApiClient(this._dioClient);

  @override
  Future<ServerDelta> pullChanges(DateTime? lastSyncedAt) async {
    try {
      final response = await _dioClient.dio.get(
        '/api/sync/pull',
        queryParameters: {
          if (lastSyncedAt != null)
            'lastSyncedAt': lastSyncedAt.toIso8601String(),
        },
      );

      return ServerDelta.fromJson(response.data as Map<String, dynamic>);
    } on DioException {
      rethrow;
    }
  }

  @override
  Future<List<PushResult>> pushChanges(List<SyncPushItem> items) async {
    try {
      final response = await _dioClient.dio.post(
        '/api/sync/push',
        data: items.map((e) => e.toJson()).toList(),
      );

      final List<dynamic> list = response.data as List<dynamic>;
      return list
          .map((e) => PushResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException {
      rethrow;
    }
  }
}
