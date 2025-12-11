import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import 'sync_api_client.dart';

/// 同步 API 客户端实现
///
/// 使用 Dio 调用后端 REST API 进行数据同步
class SyncApiClientImpl implements SyncApiClient {
  SyncApiClientImpl({
    required Dio dio,
    String basePath = '/api/sync',
  })  : _dio = dio,
        _basePath = basePath;

  final Dio _dio;
  final String _basePath;
  final _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  @override
  Future<ServerDelta> pullChanges(DateTime? lastSyncedAt) async {
    _logger.d('拉取增量数据, lastSyncedAt: $lastSyncedAt');

    try {
      final response = await _dio.post(
        '$_basePath/pull',
        data: {
          if (lastSyncedAt != null)
            'lastSyncedAt': lastSyncedAt.toIso8601String(),
        },
      );

      if (response.statusCode == 200) {
        final delta = ServerDelta.fromJson(response.data as Map<String, dynamic>);
        _logger.i('拉取成功: ${delta.customers.length} 客户, '
            '${delta.clues.length} 线索, '
            '${delta.followRecords.length} 跟进记录');
        return delta;
      }

      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: '拉取数据失败: ${response.statusCode}',
      );
    } on DioException catch (e) {
      _logger.e('拉取数据失败: ${e.message}');
      rethrow;
    }
  }

  @override
  Future<List<PushResult>> pushChanges(List<SyncPushItem> items) async {
    if (items.isEmpty) {
      return [];
    }

    _logger.d('推送 ${items.length} 个变更项');

    try {
      final response = await _dio.post(
        '$_basePath/push',
        data: {
          'changes': items.map((e) => e.toJson()).toList(),
        },
      );

      if (response.statusCode == 200) {
        final results = (response.data['results'] as List<dynamic>)
            .map((e) => PushResult.fromJson(e as Map<String, dynamic>))
            .toList();

        final successCount = results.where((r) => r.isSuccess).length;
        final conflictCount = results.where((r) => r.isConflict).length;
        final errorCount = results.where((r) => r.isError).length;

        _logger.i('推送完成: 成功 $successCount, 冲突 $conflictCount, 错误 $errorCount');
        return results;
      }

      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        message: '推送数据失败: ${response.statusCode}',
      );
    } on DioException catch (e) {
      _logger.e('推送数据失败: ${e.message}');
      rethrow;
    }
  }
}

/// Mock 同步 API 客户端
///
/// 用于开发和测试，模拟后端 API 响应
class MockSyncApiClient implements SyncApiClient {
  MockSyncApiClient();

  final _logger = Logger(printer: PrettyPrinter(methodCount: 0));

  @override
  Future<ServerDelta> pullChanges(DateTime? lastSyncedAt) async {
    _logger.d('[Mock] 拉取增量数据, lastSyncedAt: $lastSyncedAt');

    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 500));

    // 返回空增量（模拟无新数据）
    return ServerDelta(
      serverTimestamp: DateTime.now(),
    );
  }

  @override
  Future<List<PushResult>> pushChanges(List<SyncPushItem> items) async {
    _logger.d('[Mock] 推送 ${items.length} 个变更项');

    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 300));

    // 模拟全部成功
    return items.map((item) {
      return PushResult(
        localId: item.localId,
        status: 'success',
        serverId: item.operation == 'create' ? 'server_${item.localId}' : null,
        serverUpdatedAt: DateTime.now(),
      );
    }).toList();
  }
}
