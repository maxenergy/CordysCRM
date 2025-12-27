# Design Document: Core Data Integrity

## Overview

本设计文档描述了 CordysCRM 核心数据完整性修复方案，解决分析报告中识别的 P0 级别问题。设计分为两个主要部分：

1. **后端数据规范化** - 企业信用代码标准化和数据库约束
2. **Flutter 同步增强** - 离线同步状态管理和错误处理优化

设计目标：
- 消除数据重复导入风险
- 防止离线数据丢失
- 提升系统健壮性和可靠性

## Architecture

### 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter App (Mobile)                      │
├─────────────────────────────────────────────────────────────┤
│  SyncService (Enhanced)                                      │
│  ├── State Recovery (启动自愈)                               │
│  ├── Error Classification (错误分类)                         │
│  ├── Retry Strategy (智能重试)                               │
│  └── Client Monitor (API 监控)                               │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼ REST API
┌─────────────────────────────────────────────────────────────┐
│                    Backend (Spring Boot)                     │
├─────────────────────────────────────────────────────────────┤
│  EnterpriseService (Enhanced)                                │
│  ├── Credit Code Normalizer (规范化器)                       │
│  └── Deduplication Logic (去重逻辑)                          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Database (MySQL)                          │
├─────────────────────────────────────────────────────────────┤
│  enterprise_profile                                          │
│  ├── credit_code (UNIQUE INDEX)                              │
│  └── ...                                                     │
│                                                              │
│  sync_queue (Enhanced)                                       │
│  ├── attempt_count (NEW)                                     │
│  ├── error_type (NEW)                                        │
│  └── ...                                                     │
└─────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. Credit Code Normalizer (后端)

**职责**: 标准化企业信用代码格式

**接口**:
```java
public interface CreditCodeNormalizer {
    /**
     * 规范化信用代码
     * @param creditCode 原始信用代码
     * @return 规范化后的信用代码，如果输入为 null 则返回 null
     */
    String normalize(String creditCode);
}
```

**实现逻辑**:
1. 检查 null 或空字符串 → 返回 null
2. Trim 首尾空白
3. 转换为大写
4. 全角转半角（A-Z, 0-9）
5. 验证格式（18位字母数字）

**示例**:
```java
normalize("  91110000600037341L  ") → "91110000600037341L"
normalize("９１１１０００００６０００３７３４１Ｌ") → "91110000600037341L"
normalize(null) → null
normalize("") → null
```

### 2. Database Migration Script (后端)

**职责**: 安全地清理重复数据并添加唯一索引

**Flyway 脚本结构**:
```sql
-- V1.6.0_1__cleanup_duplicate_credit_codes.sql

-- Step 1: 备份原始数据
CREATE TABLE enterprise_profile_backup_20241227 AS 
SELECT * FROM enterprise_profile;

-- Step 2: 识别重复记录
CREATE TEMPORARY TABLE duplicate_credit_codes AS
SELECT credit_code, COUNT(*) as cnt, MIN(id) as keep_id
FROM enterprise_profile
WHERE credit_code IS NOT NULL AND credit_code != ''
GROUP BY credit_code
HAVING COUNT(*) > 1;

-- Step 3: 删除重复记录（保留 ID 最小的）
DELETE FROM enterprise_profile
WHERE id IN (
    SELECT ep.id
    FROM enterprise_profile ep
    INNER JOIN duplicate_credit_codes dcc 
        ON ep.credit_code = dcc.credit_code
    WHERE ep.id != dcc.keep_id
);

-- Step 4: 添加唯一索引
ALTER TABLE enterprise_profile
ADD UNIQUE INDEX uk_credit_code (credit_code);

-- Step 5: 记录迁移日志
INSERT INTO migration_log (version, description, affected_rows, created_at)
VALUES ('1.6.0_1', 'Cleanup duplicate credit codes', 
        (SELECT COUNT(*) FROM duplicate_credit_codes), NOW());
```

### 3. Sync State Recovery (Flutter)

**职责**: 启动时恢复卡死的同步状态

**接口**:
```dart
class SyncStateRecovery {
  /// 重置长时间处于 InProgress 状态的队列项
  Future<int> resetStaleInProgressItems({
    Duration staleThreshold = const Duration(minutes: 5),
  });
  
  /// 验证同步队列完整性
  Future<bool> validateQueueIntegrity();
}
```

**实现逻辑**:
```dart
Future<int> resetStaleInProgressItems() async {
  final staleTimestamp = DateTime.now().subtract(staleThreshold);
  
  // 查找 stale 项
  final staleItems = await _database.syncQueueDao
      .findInProgressBefore(staleTimestamp);
  
  if (staleItems.isEmpty) return 0;
  
  // 记录警告日志
  _logger.w('Found ${staleItems.length} stale in-progress items, resetting...');
  
  // 批量重置为 Pending
  for (final item in staleItems) {
    await _database.syncQueueDao.updateStatus(
      item.id,
      SyncStatus.pending,
    );
    _logger.w('Reset stale item: ${item.id}, entity: ${item.entityType}');
  }
  
  return staleItems.length;
}
```

### 4. Error Classifier (Flutter)

**职责**: 分类同步错误为可重试/不可重试

**接口**:
```dart
enum ErrorType {
  retryable,      // 可重试（5xx, 网络超时）
  nonRetryable,   // 不可重试（4xx）
  fatal,          // 致命错误（超过重试次数）
}

class ErrorClassifier {
  /// 分类错误类型
  ErrorType classify(dynamic error);
  
  /// 判断是否应该重试
  bool shouldRetry(ErrorType type, int attemptCount);
}
```

**实现逻辑**:
```dart
ErrorType classify(dynamic error) {
  if (error is DioException) {
    // 网络错误 - 可重试
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return ErrorType.retryable;
    }
    
    // HTTP 错误
    final statusCode = error.response?.statusCode;
    if (statusCode != null) {
      if (statusCode >= 400 && statusCode < 500) {
        return ErrorType.nonRetryable;  // 4xx 客户端错误
      }
      if (statusCode >= 500) {
        return ErrorType.retryable;     // 5xx 服务器错误
      }
    }
  }
  
  // 默认可重试
  return ErrorType.retryable;
}

bool shouldRetry(ErrorType type, int attemptCount) {
  if (type == ErrorType.nonRetryable) return false;
  if (type == ErrorType.fatal) return false;
  if (attemptCount >= 5) return false;  // 超过最大重试次数
  return true;
}
```

### 5. Sync Statistics Tracker (Flutter)

**职责**: 跟踪同步失败统计，区分错误类型

**接口**:
```dart
class SyncStatistics {
  int retryableFailedCount = 0;
  int nonRetryableFailedCount = 0;
  int successCount = 0;
  
  void recordSuccess();
  void recordFailure(ErrorType type);
  void reset();
  bool shouldTriggerGlobalRetry();
}
```

**实现逻辑**:
```dart
bool shouldTriggerGlobalRetry() {
  // 只有存在可重试错误时才触发全局重试
  return retryableFailedCount > 0;
}
```

### 6. API Client Monitor (Flutter)

**职责**: 监控 API Client 状态，防止数据丢失

**接口**:
```dart
class ApiClientMonitor {
  /// 检查 API Client 是否可用
  bool isClientAvailable();
  
  /// 注册状态变化监听器
  void addListener(VoidCallback listener);
  
  /// 移除监听器
  void removeListener(VoidCallback listener);
}
```

**实现逻辑**:
```dart
Future<void> _processSyncItem(SyncQueueItem item) async {
  // 检查 API Client 可用性
  if (!_clientMonitor.isClientAvailable()) {
    _logger.w('API Client not available, pausing sync for item ${item.id}');
    // 不删除队列项，等待 client 恢复
    return;
  }
  
  // 正常同步逻辑
  // ...
}
```

## Data Models

### Enhanced SyncQueue Table

```sql
CREATE TABLE sync_queue (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  entity_type VARCHAR(50) NOT NULL,
  entity_id BIGINT NOT NULL,
  operation VARCHAR(20) NOT NULL,  -- CREATE, UPDATE, DELETE
  status VARCHAR(20) NOT NULL,     -- PENDING, IN_PROGRESS, FAILED, FATAL_ERROR
  payload JSON,
  attempt_count INT DEFAULT 0,     -- NEW: 重试次数
  error_type VARCHAR(20),          -- NEW: 错误类型
  error_message TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_status (status),
  INDEX idx_updated_at (updated_at)
);
```

### Dart Model

```dart
@DataClassName('SyncQueueItem')
class SyncQueueTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entityType => text().withLength(min: 1, max: 50)();
  IntColumn get entityId => integer()();
  TextColumn get operation => text().withLength(min: 1, max: 20)();
  TextColumn get status => text().withLength(min: 1, max: 20)();
  TextColumn get payload => text().nullable()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();  // NEW
  TextColumn get errorType => text().nullable()();                           // NEW
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
```


## Correctness Properties

*属性（Property）是系统应该在所有有效执行中保持为真的特征或行为——本质上是关于系统应该做什么的形式化陈述。属性作为人类可读规范和机器可验证正确性保证之间的桥梁。*

### Property 1: 信用代码规范化幂等性
*For any* 信用代码字符串，对其进行两次规范化操作应该产生相同的结果
**Validates: Requirements 1.1, 1.2, 1.3**

### Property 2: 信用代码规范化保留 null
*For any* null 或空字符串输入，规范化操作应该返回 null
**Validates: Requirements 1.4**

### Property 3: 全角半角转换正确性
*For any* 包含全角字符（A-Z, 0-9）的信用代码，规范化后应该只包含对应的半角字符
**Validates: Requirements 1.3**

### Property 4: Stale 项重置时间阈值
*For any* 更新时间超过 5 分钟的 InProgress 状态队列项，启动时应该被重置为 Pending 状态
**Validates: Requirements 3.2**

### Property 5: 错误分类一致性
*For any* HTTP 状态码在 400-499 范围内的错误，应该被分类为 Non_Retryable_Error
**Validates: Requirements 4.1**

### Property 6: 错误分类一致性（服务器错误）
*For any* HTTP 状态码在 500-599 范围内的错误，应该被分类为 Retryable_Error
**Validates: Requirements 4.2**

### Property 7: 重试次数递增
*For any* 同步队列项，每次重试后 attempt_count 应该递增 1
**Validates: Requirements 7.2**

### Property 8: 指数退避间隔
*For any* 可重试错误，第 n 次重试的等待时间应该约等于 2^n 秒（允许 ±20% 误差）
**Validates: Requirements 4.5**

### Property 9: 数据库唯一约束生效
*For any* 两个具有相同规范化后 credit_code 的企业记录，尝试插入第二条应该失败
**Validates: Requirements 1.5**

### Property 10: 迁移回滚完整性
*For any* 迁移失败场景，数据库状态应该与迁移前完全一致
**Validates: Requirements 8.2**

## Error Handling

### 1. 数据规范化错误

**场景**: 信用代码格式无效

**处理策略**:
```java
public String normalize(String creditCode) {
    if (creditCode == null || creditCode.trim().isEmpty()) {
        return null;
    }
    
    try {
        String normalized = creditCode.trim()
                                      .toUpperCase()
                                      .replaceAll("[Ａ-Ｚ０-９]", this::toHalfWidth);
        
        // 验证格式
        if (!normalized.matches("[0-9A-Z]{18}")) {
            _logger.warn("Invalid credit code format: {}", creditCode);
            // 返回规范化结果，但记录警告
            return normalized;
        }
        
        return normalized;
    } catch (Exception e) {
        _logger.error("Failed to normalize credit code: {}", creditCode, e);
        // 返回原始值，避免数据丢失
        return creditCode;
    }
}
```

### 2. 数据迁移错误

**场景**: 迁移过程中数据库连接中断

**处理策略**:
```sql
-- 使用事务确保原子性
START TRANSACTION;

-- 迁移操作
-- ...

-- 验证结果
SELECT COUNT(*) INTO @duplicate_count
FROM enterprise_profile
GROUP BY credit_code
HAVING COUNT(*) > 1;

IF @duplicate_count > 0 THEN
    ROLLBACK;
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Migration failed: duplicates still exist';
ELSE
    COMMIT;
END IF;
```

### 3. 同步状态恢复错误

**场景**: 数据库查询失败

**处理策略**:
```dart
Future<void> initialize() async {
  try {
    final resetCount = await _stateRecovery.resetStaleInProgressItems();
    _logger.i('Reset $resetCount stale items during initialization');
  } catch (e, stackTrace) {
    _logger.e('Failed to reset stale items', e, stackTrace);
    // 抛出初始化异常，阻止服务启动
    throw SyncInitializationException(
      'Failed to recover sync state: $e',
      originalError: e,
      stackTrace: stackTrace,
    );
  }
}
```

### 4. API Client 不可用错误

**场景**: 用户尝试创建离线数据但未配置服务器

**处理策略**:
```dart
Future<void> createCustomer(Customer customer) async {
  if (!_clientMonitor.isClientAvailable()) {
    throw ApiClientUnavailableException(
      'Cannot create customer: API server not configured. '
      'Please configure server URL in settings.',
    );
  }
  
  // 正常创建逻辑
  // ...
}
```

### 5. 重试次数超限错误

**场景**: 同步任务重试 5 次后仍然失败

**处理策略**:
```dart
Future<void> _processSyncItem(SyncQueueItem item) async {
  if (item.attemptCount >= 5) {
    _logger.e('Item ${item.id} exceeded max retry attempts, marking as fatal');
    await _database.syncQueueDao.updateStatus(
      item.id,
      SyncStatus.fatalError,
    );
    // 发送通知给用户
    _notificationService.showError(
      'Sync failed permanently for ${item.entityType} #${item.entityId}. '
      'Please check your network and try manual sync.',
    );
    return;
  }
  
  // 正常同步逻辑
  // ...
}
```

## Testing Strategy

### 测试方法

本项目采用**双重测试策略**：

1. **单元测试** - 验证具体示例、边界条件和错误处理
2. **属性测试** - 验证通用属性在所有输入下成立

两者互补，共同保证系统正确性。

### 后端测试（Java + jqwik）

#### 1. 信用代码规范化属性测试

```java
@Property
void creditCodeNormalizationIsIdempotent(@ForAll String creditCode) {
    String normalized1 = normalizer.normalize(creditCode);
    String normalized2 = normalizer.normalize(normalized1);
    
    assertThat(normalized1).isEqualTo(normalized2);
}

@Property
void creditCodeNormalizationPreservesNull(@ForAll @From("nullOrEmpty") String input) {
    String result = normalizer.normalize(input);
    assertThat(result).isNull();
}

@Provide
Arbitrary<String> nullOrEmpty() {
    return Arbitraries.of(null, "", "   ", "\t\n");
}

@Property
void fullWidthToHalfWidthConversion(@ForAll @CharRange(from = 'Ａ', to = 'Ｚ') char fullWidth) {
    String input = String.valueOf(fullWidth);
    String result = normalizer.normalize(input);
    
    // 验证转换为半角
    assertThat(result).matches("[A-Z]");
}
```

#### 2. 数据库唯一约束测试

```java
@Test
void shouldPreventDuplicateCreditCodes() {
    // 插入第一条记录
    EnterpriseProfile enterprise1 = new EnterpriseProfile();
    enterprise1.setCreditCode("91110000600037341L");
    enterpriseService.save(enterprise1);
    
    // 尝试插入重复记录
    EnterpriseProfile enterprise2 = new EnterpriseProfile();
    enterprise2.setCreditCode("91110000600037341L");
    
    assertThatThrownBy(() -> enterpriseService.save(enterprise2))
        .isInstanceOf(DuplicateKeyException.class);
}
```

### Flutter 测试（Dart + fast_check）

#### 1. Stale 项重置属性测试

```dart
test('Property: stale items are reset based on time threshold', () async {
  await fc.assert(
    fc.asyncProperty(
      fc.integer(min: 0, max: 10),  // minutes ago
      (minutesAgo) async {
        // 创建测试队列项
        final item = SyncQueueItem(
          id: 1,
          entityType: 'customer',
          entityId: 100,
          operation: 'CREATE',
          status: SyncStatus.inProgress,
          updatedAt: DateTime.now().subtract(Duration(minutes: minutesAgo)),
        );
        
        await database.syncQueueDao.insert(item);
        
        // 执行重置
        final resetCount = await stateRecovery.resetStaleInProgressItems(
          staleThreshold: Duration(minutes: 5),
        );
        
        // 验证：超过 5 分钟的应该被重置
        if (minutesAgo > 5) {
          expect(resetCount, equals(1));
          final updated = await database.syncQueueDao.findById(1);
          expect(updated.status, equals(SyncStatus.pending));
        } else {
          expect(resetCount, equals(0));
        }
      },
    ),
    numRuns: 100,
  );
});
```

#### 2. 错误分类属性测试

```dart
test('Property: 4xx errors are classified as non-retryable', () async {
  await fc.assert(
    fc.asyncProperty(
      fc.integer(min: 400, max: 499),  // 4xx status codes
      (statusCode) async {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: statusCode,
          ),
        );
        
        final errorType = errorClassifier.classify(error);
        expect(errorType, equals(ErrorType.nonRetryable));
      },
    ),
    numRuns: 100,
  );
});

test('Property: 5xx errors are classified as retryable', () async {
  await fc.assert(
    fc.asyncProperty(
      fc.integer(min: 500, max: 599),  // 5xx status codes
      (statusCode) async {
        final error = DioException(
          requestOptions: RequestOptions(path: '/test'),
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: statusCode,
          ),
        );
        
        final errorType = errorClassifier.classify(error);
        expect(errorType, equals(ErrorType.retryable));
      },
    ),
    numRuns: 100,
  );
});
```

#### 3. 重试次数递增属性测试

```dart
test('Property: attempt count increments on each retry', () async {
  await fc.assert(
    fc.asyncProperty(
      fc.integer(min: 0, max: 10),  // initial attempt count
      (initialCount) async {
        final item = SyncQueueItem(
          id: 1,
          entityType: 'customer',
          entityId: 100,
          operation: 'CREATE',
          status: SyncStatus.pending,
          attemptCount: initialCount,
        );
        
        await database.syncQueueDao.insert(item);
        
        // 模拟重试
        await syncService.retryItem(item.id);
        
        // 验证计数器递增
        final updated = await database.syncQueueDao.findById(1);
        expect(updated.attemptCount, equals(initialCount + 1));
      },
    ),
    numRuns: 100,
  );
});
```

#### 4. 指数退避属性测试

```dart
test('Property: exponential backoff intervals', () async {
  await fc.assert(
    fc.asyncProperty(
      fc.integer(min: 1, max: 5),  // retry attempt number
      (attemptNumber) async {
        final expectedDelay = pow(2, attemptNumber).toInt();
        final actualDelay = syncService.calculateBackoffDelay(attemptNumber);
        
        // 允许 ±20% 误差（考虑 jitter）
        final lowerBound = (expectedDelay * 0.8).toInt();
        final upperBound = (expectedDelay * 1.2).toInt();
        
        expect(actualDelay, inInclusiveRange(lowerBound, upperBound));
      },
    ),
    numRuns: 100,
  );
});
```

### 集成测试

#### 1. 端到端同步测试

```dart
testWidgets('E2E: offline data survives app restart', (tester) async {
  // 1. 创建离线数据
  await tester.pumpWidget(MyApp());
  await tester.tap(find.byKey(Key('create_customer_button')));
  await tester.enterText(find.byKey(Key('customer_name')), 'Test Customer');
  await tester.tap(find.byKey(Key('save_button')));
  await tester.pumpAndSettle();
  
  // 2. 验证数据在队列中
  final queueItems = await database.syncQueueDao.findAll();
  expect(queueItems, hasLength(1));
  expect(queueItems.first.status, equals(SyncStatus.pending));
  
  // 3. 模拟应用重启
  await tester.pumpWidget(Container());
  await tester.pumpWidget(MyApp());
  await tester.pumpAndSettle();
  
  // 4. 验证数据仍在队列中
  final queueItemsAfterRestart = await database.syncQueueDao.findAll();
  expect(queueItemsAfterRestart, hasLength(1));
  expect(queueItemsAfterRestart.first.status, equals(SyncStatus.pending));
});
```

### 测试配置

所有属性测试应配置为运行至少 **100 次迭代**：

```dart
// Dart
await fc.assert(
  fc.asyncProperty(...),
  numRuns: 100,  // 最少 100 次
);
```

```java
// Java
@Property(tries = 100)  // 最少 100 次
void myPropertyTest(@ForAll ...) {
    // ...
}
```

### 测试标签

每个属性测试必须使用注释标记其验证的设计属性：

```dart
// Feature: core-data-integrity, Property 4: Stale 项重置时间阈值
test('Property: stale items are reset based on time threshold', () async {
  // ...
});
```

```java
/**
 * Feature: core-data-integrity, Property 1: 信用代码规范化幂等性
 */
@Property
void creditCodeNormalizationIsIdempotent(@ForAll String creditCode) {
    // ...
}
```

