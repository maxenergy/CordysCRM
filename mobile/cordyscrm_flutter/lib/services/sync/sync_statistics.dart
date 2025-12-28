import '../../core/error/error_classifier.dart';

/// 同步失败统计
///
/// 用于跟踪单次同步会话的统计信息，区分可重试和不可重试的错误类型。
/// 统计数据用于决定是否需要触发全局重试。
class SyncStatistics {
  int _retryableFailedCount = 0;
  int _nonRetryableFailedCount = 0;
  int _successCount = 0;

  /// 可重试失败次数
  int get retryableFailedCount => _retryableFailedCount;

  /// 不可重试失败次数
  int get nonRetryableFailedCount => _nonRetryableFailedCount;

  /// 成功次数
  int get successCount => _successCount;

  /// 总失败次数
  int get totalFailedCount => _retryableFailedCount + _nonRetryableFailedCount;

  /// 记录成功
  void recordSuccess() {
    _successCount++;
  }

  /// 记录失败
  ///
  /// 根据错误类型更新相应的计数器。
  /// Fatal 错误不计入统计，因为它们已经超过重试次数限制。
  void recordFailure(ErrorType type) {
    if (type == ErrorType.retryable) {
      _retryableFailedCount++;
    } else if (type == ErrorType.nonRetryable) {
      _nonRetryableFailedCount++;
    }
    // Fatal 错误不计入统计
  }

  /// 重置所有计数器
  ///
  /// 应在每次同步会话开始时调用。
  void reset() {
    _retryableFailedCount = 0;
    _nonRetryableFailedCount = 0;
    _successCount = 0;
  }

  /// 是否应该触发全局重试
  ///
  /// 核心逻辑：只有存在可重试错误时才触发全局重试。
  /// 如果所有失败都是不可重试的（如 4xx 客户端错误），则不需要重试。
  ///
  /// Requirements: 5.3, 5.4
  bool shouldTriggerGlobalRetry() {
    return _retryableFailedCount > 0;
  }

  @override
  String toString() {
    return 'SyncStatistics(success: $_successCount, '
        'retryableFailed: $_retryableFailedCount, '
        'nonRetryableFailed: $_nonRetryableFailedCount)';
  }
}
