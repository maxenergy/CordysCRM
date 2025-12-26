import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cordyscrm_flutter/domain/entities/enterprise.dart';
import 'package:cordyscrm_flutter/domain/repositories/enterprise_repository.dart';
import 'package:cordyscrm_flutter/presentation/features/enterprise/enterprise_provider.dart';
import 'package:cordyscrm_flutter/core/utils/enterprise_url_utils.dart';

// ==================== Test Utilities ====================

final random = Random();

String randomString(int length) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return List.generate(length, (_) => chars[random.nextInt(chars.length)])
      .join();
}

String randomName() {
  const prefixes = ['北京', '上海', '广州', '深圳', '杭州'];
  const suffixes = ['科技有限公司', '信息有限公司', '贸易有限公司', '集团有限公司'];
  return '${prefixes[random.nextInt(prefixes.length)]}${randomString(4)}${suffixes[random.nextInt(suffixes.length)]}';
}

/// 生成一批 creditCode（用于控制重复率）
List<String> buildCreditCodePool(int size) {
  return List.generate(size, (_) => 'CC_${randomString(8)}');
}

/// 生成 Enterprise 列表
List<Enterprise> generateEnterprises({
  required int count,
  required String source,
  double duplicateRate = 0.3, // 30% 使用重复值
  double emptyRate = 0.1, // 10% 空 creditCode
  List<String>? creditCodePool,
}) {
  final pool = creditCodePool ??
      buildCreditCodePool(max(1, (count * (1 - duplicateRate)).ceil()));
  
  // 防止空 pool 导致崩溃
  if (pool.isEmpty) {
    return List.generate(count, (i) => Enterprise(
      id: 'ent_${randomString(10)}',
      name: randomName(),
      creditCode: 'CC_${randomString(8)}',
      source: source,
      legalPerson: randomString(3),
      address: randomString(6),
      industry: randomString(4),
    ));
  }
  
  return List.generate(count, (i) {
    String creditCode;
    final roll = random.nextDouble();
    if (roll < emptyRate) {
      creditCode = '';
    } else if (roll < emptyRate + duplicateRate) {
      creditCode = pool[random.nextInt(pool.length)];
    } else {
      creditCode = 'CC_${randomString(8)}';
    }

    return Enterprise(
      id: 'ent_${randomString(10)}',
      name: randomName(),
      creditCode: creditCode,
      source: source,
      legalPerson: randomString(3),
      address: randomString(6),
      industry: randomString(4),
    );
  });
}

// ==================== Fake Repository ====================

typedef SearchHandler = Future<EnterpriseSearchResult> Function(String keyword);

class FakeEnterpriseRepository implements EnterpriseRepository {
  FakeEnterpriseRepository({
    SearchHandler? qccHandler,
    SearchHandler? iqichaHandler,
  })  : _qccHandler = qccHandler,
        _iqichaHandler = iqichaHandler;

  final SearchHandler? _qccHandler;
  final SearchHandler? _iqichaHandler;

  @override
  Future<EnterpriseSearchResult> searchQichacha({required String keyword}) async {
    if (_qccHandler == null) {
      return const EnterpriseSearchResult(success: true, items: [], total: 0);
    }
    return _qccHandler(keyword);
  }

  @override
  Future<EnterpriseSearchResult> searchAiqicha({
    required String keyword,
    int page = 1,
    int pageSize = 10,
  }) async {
    if (_iqichaHandler == null) {
      return const EnterpriseSearchResult(success: true, items: [], total: 0);
    }
    return _iqichaHandler(keyword);
  }

  @override
  Future<EnterpriseSearchResult> searchLocal({
    required String keyword,
    int page = 1,
    int pageSize = 10,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<EnterpriseSearchResult> searchEnterprise({
    required String keyword,
    int page = 1,
    int pageSize = 10,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<EnterpriseImportResult> importEnterprise({
    required Enterprise enterprise,
    bool forceOverwrite = false,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> saveCookies(Map<String, String> cookies) async {}

  @override
  Future<Map<String, String>> loadCookies() async => {};

  @override
  Future<void> clearCookies() async {}

  @override
  Future<void> saveUserAgent(String userAgent) async {}

  @override
  Future<String?> loadUserAgent() async => null;
}

// ==================== Property Tests ====================

/// **Feature: enterprise-research, Property 5: 错误处理保留本地结果**
/// **Validates: Requirements 2.5, 4.2**
///
/// For any 重新搜索失败场景，本地结果应该保持不变，
/// 且应该设置 reSearchError 而不影响原有数据。
void main() {
  group('Property 5: 错误处理保留本地结果', () {
    test('should preserve local results when re-search fails with error result',
        () async {
      // 运行 30 次迭代
      for (var iteration = 0; iteration < 30; iteration++) {
        // 生成随机本地结果 (5-20 条)
        final localCount = random.nextInt(16) + 5;
        final localResults = generateEnterprises(
          count: localCount,
          source: 'local',
        );

        // 生成随机错误消息（覆盖不同错误类型）
        final errorMessages = [
          '请先打开企查查页面',
          'WebView 未就绪',
          '需要登录验证',
          '验证码错误',
          '网络连接失败',
          '请求超时',
          'timeout',
          'connection failed',
          '未知错误',
        ];
        final errorMessage = errorMessages[random.nextInt(errorMessages.length)];

        // 创建失败的 Repository
        final repo = FakeEnterpriseRepository(
          qccHandler: (keyword) async =>
              EnterpriseSearchResult.error(errorMessage),
        );

        // 创建 ProviderContainer
        final container = ProviderContainer(
          overrides: [
            enterpriseRepositoryProvider.overrideWithValue(repo),
            enterpriseDataSourceTypeProvider
                .overrideWith((ref) => EnterpriseDataSourceType.qcc),
          ],
        );

        final notifier = container.read(enterpriseSearchProvider.notifier);

        // 设置初始状态（模拟已有本地结果）
        notifier.state = EnterpriseSearchState(
          results: localResults,
          total: localResults.length,
          keyword: '测试${randomString(3)}',
          dataSource: EnterpriseSearchDataSource.local,
        );

        // 执行重新搜索
        await notifier.reSearchExternal();

        final state = notifier.state;

        // 断言：本地结果完全不变
        expect(state.results, equals(localResults),
            reason:
                'Iteration $iteration: Local results should be preserved after re-search failure');
        expect(state.total, equals(localResults.length),
            reason:
                'Iteration $iteration: Total count should remain unchanged');
        expect(state.dataSource, equals(EnterpriseSearchDataSource.local),
            reason:
                'Iteration $iteration: Data source should remain local after failure');

        // 断言：错误状态正确设置
        expect(state.reSearchError, isNotNull,
            reason:
                'Iteration $iteration: reSearchError should be set on failure');
        expect(state.isReSearching, isFalse,
            reason:
                'Iteration $iteration: isReSearching should be false after completion');
        expect(state.reSearchNotice, isNull,
            reason:
                'Iteration $iteration: reSearchNotice should be null on failure');

        container.dispose();
      }
    });

    test('should preserve local results when re-search throws exception',
        () async {
      // 运行 30 次迭代
      for (var iteration = 0; iteration < 30; iteration++) {
        // 生成随机本地结果 (3-15 条)
        final localCount = random.nextInt(13) + 3;
        final localResults = generateEnterprises(
          count: localCount,
          source: 'local',
        );

        // 创建抛异常的 Repository
        final repo = FakeEnterpriseRepository(
          qccHandler: (keyword) async =>
              throw Exception('Network error: ${randomString(5)}'),
        );

        // 创建 ProviderContainer
        final container = ProviderContainer(
          overrides: [
            enterpriseRepositoryProvider.overrideWithValue(repo),
            enterpriseDataSourceTypeProvider
                .overrideWith((ref) => EnterpriseDataSourceType.qcc),
          ],
        );

        final notifier = container.read(enterpriseSearchProvider.notifier);

        // 设置初始状态
        notifier.state = EnterpriseSearchState(
          results: localResults,
          total: localResults.length,
          keyword: '测试${randomString(3)}',
          dataSource: EnterpriseSearchDataSource.local,
        );

        // 执行重新搜索
        await notifier.reSearchExternal();

        final state = notifier.state;

        // 断言：本地结果完全不变
        expect(state.results, equals(localResults),
            reason:
                'Iteration $iteration: Local results should be preserved when exception thrown');
        expect(state.total, equals(localResults.length));
        expect(state.dataSource, equals(EnterpriseSearchDataSource.local));

        // 断言：错误状态正确设置
        expect(state.reSearchError, isNotNull);
        expect(state.isReSearching, isFalse);

        container.dispose();
      }
    });
  });

  group('Property 3: 结果排序与合并', () {
    test('should merge results with local first and deduplicated external after',
        () async {
      // 运行 30 次迭代
      for (var iteration = 0; iteration < 30; iteration++) {
        // 生成本地结果 (5-15 条)
        final localCount = random.nextInt(11) + 5;
        final localResults = generateEnterprises(
          count: localCount,
          source: 'local',
          emptyRate: 0.1, // 10% 空 creditCode
        );

        // 提取本地 creditCode 用于制造重复
        final localCreditCodes = localResults
            .map((e) => e.creditCode)
            .where((code) => code.isNotEmpty)
            .toList();

        // 生成外部结果 (10-25 条)
        final externalCount = random.nextInt(16) + 10;
        final externalResults = generateEnterprises(
          count: externalCount,
          source: 'qcc',
          duplicateRate: 0.3, // 30% 使用重复值（降低重复率确保有新结果）
          emptyRate: 0.15, // 15% 空 creditCode
          creditCodePool: localCreditCodes, // 使用本地 creditCode 制造重复
        );
        
        // 确保至少有一个唯一的外部结果（防止全部去重）
        final uniqueExternal = Enterprise(
          id: 'ent_unique_${randomString(10)}',
          name: randomName(),
          creditCode: 'CC_UNIQUE_${randomString(8)}',
          source: 'qcc',
          legalPerson: randomString(3),
          address: randomString(6),
          industry: randomString(4),
        );
        externalResults.add(uniqueExternal);

        // 创建成功的 Repository
        final repo = FakeEnterpriseRepository(
          qccHandler: (keyword) async => EnterpriseSearchResult(
            success: true,
            items: externalResults,
            total: externalResults.length,
          ),
        );

        // 创建 ProviderContainer
        final container = ProviderContainer(
          overrides: [
            enterpriseRepositoryProvider.overrideWithValue(repo),
            enterpriseDataSourceTypeProvider
                .overrideWith((ref) => EnterpriseDataSourceType.qcc),
          ],
        );

        final notifier = container.read(enterpriseSearchProvider.notifier);

        // 设置初始状态
        notifier.state = EnterpriseSearchState(
          results: localResults,
          total: localResults.length,
          keyword: '测试${randomString(3)}',
          dataSource: EnterpriseSearchDataSource.local,
        );

        // 执行重新搜索
        await notifier.reSearchExternal();

        final state = notifier.state;

        // 计算预期的去重后外部结果
        final localCreditCodeSet = localResults
            .map((e) => e.creditCode)
            .where((code) => code.isNotEmpty)
            .toSet();
        final expectedUniqueExternal = externalResults
            .where((e) =>
                e.creditCode.isEmpty ||
                !localCreditCodeSet.contains(e.creditCode))
            .toList();

        // 断言：结果顺序正确（本地在前，外部在后）
        expect(state.results.length,
            equals(localResults.length + expectedUniqueExternal.length),
            reason:
                'Iteration $iteration: Total results should be local + unique external');

        // 验证前 N 项是本地结果
        for (var i = 0; i < localResults.length; i++) {
          expect(state.results[i], equals(localResults[i]),
              reason:
                  'Iteration $iteration: Local results should be at the beginning');
        }

        // 验证后续项是去重后的外部结果
        final actualExternal =
            state.results.sublist(localResults.length).toList();
        expect(actualExternal.length, equals(expectedUniqueExternal.length),
            reason:
                'Iteration $iteration: External results should be deduplicated');
        
        // 验证外部结果顺序保持不变
        expect(actualExternal, equals(expectedUniqueExternal),
            reason:
                'Iteration $iteration: External results should preserve original order after deduplication');

        // 验证去重逻辑：外部结果中不应包含本地已有的 creditCode（空值除外）
        for (final ext in actualExternal) {
          if (ext.creditCode.isNotEmpty) {
            expect(localCreditCodeSet.contains(ext.creditCode), isFalse,
                reason:
                    'Iteration $iteration: External result with creditCode ${ext.creditCode} should not duplicate local');
          }
        }

        // 断言：状态正确更新
        expect(state.dataSource, equals(EnterpriseSearchDataSource.mixed),
            reason:
                'Iteration $iteration: Data source should be mixed after successful re-search');
        expect(
            state.externalDataSourceType, equals(EnterpriseDataSourceType.qcc),
            reason:
                'Iteration $iteration: External data source type should be set');
        expect(state.total, equals(state.results.length),
            reason: 'Iteration $iteration: Total should match results length');
        expect(state.reSearchError, isNull,
            reason:
                'Iteration $iteration: reSearchError should be null on success');
        expect(state.reSearchNotice, isNull,
            reason:
                'Iteration $iteration: reSearchNotice should be null when new results found');
        expect(state.isReSearching, isFalse,
            reason:
                'Iteration $iteration: isReSearching should be false after completion');

        container.dispose();
      }
    });

    test('should work correctly with iqicha data source', () async {
      // 运行 10 次迭代测试爱企查路径
      for (var iteration = 0; iteration < 10; iteration++) {
        // 生成本地结果 (3-8 条)
        final localCount = random.nextInt(6) + 3;
        final localResults = generateEnterprises(
          count: localCount,
          source: 'local',
          emptyRate: 0.1,
        );

        // 生成外部结果 (5-10 条)
        final externalCount = random.nextInt(6) + 5;
        final externalResults = generateEnterprises(
          count: externalCount,
          source: 'iqicha',
          emptyRate: 0.1,
        );

        // 创建成功的 Repository（使用 iqicha handler）
        final repo = FakeEnterpriseRepository(
          iqichaHandler: (keyword) async => EnterpriseSearchResult(
            success: true,
            items: externalResults,
            total: externalResults.length,
          ),
        );

        // 创建 ProviderContainer（设置为爱企查）
        final container = ProviderContainer(
          overrides: [
            enterpriseRepositoryProvider.overrideWithValue(repo),
            enterpriseDataSourceTypeProvider
                .overrideWith((ref) => EnterpriseDataSourceType.iqicha),
          ],
        );

        final notifier = container.read(enterpriseSearchProvider.notifier);

        // 设置初始状态
        notifier.state = EnterpriseSearchState(
          results: localResults,
          total: localResults.length,
          keyword: '测试${randomString(3)}',
          dataSource: EnterpriseSearchDataSource.local,
        );

        // 执行重新搜索
        await notifier.reSearchExternal();

        final state = notifier.state;

        // 断言：状态正确更新为爱企查
        expect(state.dataSource, equals(EnterpriseSearchDataSource.mixed),
            reason:
                'Iteration $iteration: Data source should be mixed for iqicha');
        expect(state.externalDataSourceType,
            equals(EnterpriseDataSourceType.iqicha),
            reason:
                'Iteration $iteration: External data source type should be iqicha');

        container.dispose();
      }
    });

    test('should show notice when no new results after deduplication',
        () async {
      // 运行 20 次迭代
      for (var iteration = 0; iteration < 20; iteration++) {
        // 生成本地结果 (5-10 条)
        final localCount = random.nextInt(6) + 5;
        final localResults = generateEnterprises(
          count: localCount,
          source: 'local',
          emptyRate: 0.0, // 确保都有 creditCode
        );

        // 生成外部结果：全部与本地重复
        final externalResults = localResults
            .map((e) => Enterprise(
                  id: 'ext_${randomString(10)}',
                  name: e.name,
                  creditCode: e.creditCode, // 使用相同的 creditCode
                  source: 'qcc',
                  legalPerson: randomString(3),
                  address: randomString(6),
                  industry: randomString(4),
                ))
            .toList();

        // 创建成功的 Repository
        final repo = FakeEnterpriseRepository(
          qccHandler: (keyword) async => EnterpriseSearchResult(
            success: true,
            items: externalResults,
            total: externalResults.length,
          ),
        );

        // 创建 ProviderContainer
        final container = ProviderContainer(
          overrides: [
            enterpriseRepositoryProvider.overrideWithValue(repo),
            enterpriseDataSourceTypeProvider
                .overrideWith((ref) => EnterpriseDataSourceType.qcc),
          ],
        );

        final notifier = container.read(enterpriseSearchProvider.notifier);

        // 设置初始状态
        notifier.state = EnterpriseSearchState(
          results: localResults,
          total: localResults.length,
          keyword: '测试${randomString(3)}',
          dataSource: EnterpriseSearchDataSource.local,
        );

        // 执行重新搜索
        await notifier.reSearchExternal();

        final state = notifier.state;

        // 断言：结果未变（全部去重）
        expect(state.results, equals(localResults),
            reason:
                'Iteration $iteration: Results should remain unchanged when all external are duplicates');
        expect(state.total, equals(localResults.length));
        expect(state.dataSource, equals(EnterpriseSearchDataSource.local),
            reason:
                'Iteration $iteration: Data source should remain local when no new results');

        // 断言：显示通知
        expect(state.reSearchNotice, isNotNull,
            reason:
                'Iteration $iteration: reSearchNotice should be set when no new results');
        expect(state.reSearchNotice, contains('未发现新结果'),
            reason:
                'Iteration $iteration: Notice should indicate no new results');
        expect(state.reSearchError, isNull,
            reason:
                'Iteration $iteration: reSearchError should be null (this is not an error)');

        container.dispose();
      }
    });
  });

  group('Property 6: 清除操作状态重置', () {
    test('should reset all state fields when clear is called', () async {
      // 运行 30 次迭代
      for (var iteration = 0; iteration < 30; iteration++) {
        // 生成随机混合状态
        final results = generateEnterprises(
          count: random.nextInt(20) + 5,
          source: random.nextBool() ? 'local' : 'qcc',
        );

        final container = ProviderContainer(
          overrides: [
            enterpriseDataSourceTypeProvider
                .overrideWith((ref) => EnterpriseDataSourceType.qcc),
          ],
        );

        final notifier = container.read(enterpriseSearchProvider.notifier);

        // 设置随机状态
        notifier.state = EnterpriseSearchState(
          isSearching: random.nextBool(),
          isReSearching: random.nextBool(),
          results: results,
          total: results.length,
          error: random.nextBool() ? '随机错误${randomString(5)}' : null,
          reSearchError: random.nextBool()
              ? ReSearchError(
                  type: ReSearchErrorType.values[
                      random.nextInt(ReSearchErrorType.values.length)],
                  message: '随机重搜错误${randomString(5)}',
                )
              : null,
          reSearchNotice: random.nextBool() ? '随机通知${randomString(5)}' : null,
          keyword: '测试${randomString(5)}',
          dataSource: EnterpriseSearchDataSource
              .values[random.nextInt(EnterpriseSearchDataSource.values.length)],
          externalDataSourceType: random.nextBool()
              ? EnterpriseDataSourceType.qcc
              : EnterpriseDataSourceType.iqicha,
          isSelectionMode: random.nextBool(),
          selectedIds: random.nextBool()
              ? {'id1', 'id2', 'id3'}
              : <String>{},
          isBatchImporting: random.nextBool(),
          importProgress: random.nextInt(10),
          importTotal: random.nextInt(20),
          importErrors: random.nextBool()
              ? [
                  BatchImportError(
                    enterprise: results.first,
                    error: '导入错误',
                  )
                ]
              : [],
        );

        // 执行清除
        notifier.clear();

        final state = notifier.state;

        // 断言：所有字段恢复默认值
        expect(state.isSearching, isFalse,
            reason: 'Iteration $iteration: isSearching should be false');
        expect(state.isReSearching, isFalse,
            reason: 'Iteration $iteration: isReSearching should be false');
        expect(state.results, isEmpty,
            reason: 'Iteration $iteration: results should be empty');
        expect(state.total, equals(0),
            reason: 'Iteration $iteration: total should be 0');
        expect(state.error, isNull,
            reason: 'Iteration $iteration: error should be null');
        expect(state.reSearchError, isNull,
            reason: 'Iteration $iteration: reSearchError should be null');
        expect(state.reSearchNotice, isNull,
            reason: 'Iteration $iteration: reSearchNotice should be null');
        expect(state.keyword, isEmpty,
            reason: 'Iteration $iteration: keyword should be empty');
        expect(state.dataSource, isNull,
            reason: 'Iteration $iteration: dataSource should be null');
        expect(state.externalDataSourceType, isNull,
            reason:
                'Iteration $iteration: externalDataSourceType should be null');
        expect(state.isSelectionMode, isFalse,
            reason: 'Iteration $iteration: isSelectionMode should be false');
        expect(state.selectedIds, isEmpty,
            reason: 'Iteration $iteration: selectedIds should be empty');
        expect(state.isBatchImporting, isFalse,
            reason: 'Iteration $iteration: isBatchImporting should be false');
        expect(state.importProgress, equals(0),
            reason: 'Iteration $iteration: importProgress should be 0');
        expect(state.importTotal, equals(0),
            reason: 'Iteration $iteration: importTotal should be 0');
        expect(state.importErrors, isEmpty,
            reason: 'Iteration $iteration: importErrors should be empty');

        container.dispose();
      }
    });
  });
}
