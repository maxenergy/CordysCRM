import '../entities/follow_record.dart';

/// 跟进记录仓库接口
abstract class FollowRecordRepository {
  /// 获取客户的跟进记录
  Future<List<FollowRecord>> getFollowRecordsByCustomerId(String customerId);

  /// 获取线索的跟进记录
  Future<List<FollowRecord>> getFollowRecordsByClueId(String clueId);

  /// 根据 ID 获取跟进记录
  Future<FollowRecord?> getFollowRecordById(String id);

  /// 创建跟进记录
  Future<FollowRecord> createFollowRecord(FollowRecord record);

  /// 更新跟进记录
  Future<FollowRecord> updateFollowRecord(FollowRecord record);

  /// 删除跟进记录
  Future<void> deleteFollowRecord(String id);
}
