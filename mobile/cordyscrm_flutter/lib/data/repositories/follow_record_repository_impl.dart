import 'package:uuid/uuid.dart';

import '../../domain/entities/follow_record.dart';
import '../../domain/repositories/follow_record_repository.dart';

/// 跟进记录仓库实现
class FollowRecordRepositoryImpl implements FollowRecordRepository {
  final Map<String, List<FollowRecord>> _customerRecords = {};
  final Map<String, List<FollowRecord>> _clueRecords = {};

  FollowRecordRepositoryImpl() {
    _initMockData();
  }

  /// 初始化数据
  /// 注意：已清空模拟数据，跟进记录应通过实际业务流程创建
  void _initMockData() {
    // 不再生成模拟数据，保持空 Map
  }

  @override
  Future<List<FollowRecord>> getFollowRecordsByCustomerId(String customerId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _customerRecords[customerId] ?? [];
  }

  @override
  Future<List<FollowRecord>> getFollowRecordsByClueId(String clueId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _clueRecords[clueId] ?? [];
  }

  @override
  Future<FollowRecord?> getFollowRecordById(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    for (final records in _customerRecords.values) {
      for (final record in records) {
        if (record.id == id) return record;
      }
    }
    for (final records in _clueRecords.values) {
      for (final record in records) {
        if (record.id == id) return record;
      }
    }
    return null;
  }

  @override
  Future<FollowRecord> createFollowRecord(FollowRecord record) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final newRecord = FollowRecord(
      id: const Uuid().v4(),
      customerId: record.customerId,
      clueId: record.clueId,
      content: record.content,
      followType: record.followType,
      followAt: record.followAt,
      createdBy: record.createdBy ?? '当前用户',
      images: record.images,
      audioUrl: record.audioUrl,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (record.customerId != null) {
      _customerRecords.putIfAbsent(record.customerId!, () => []);
      _customerRecords[record.customerId!]!.insert(0, newRecord);
    }
    if (record.clueId != null) {
      _clueRecords.putIfAbsent(record.clueId!, () => []);
      _clueRecords[record.clueId!]!.insert(0, newRecord);
    }

    return newRecord;
  }

  @override
  Future<FollowRecord> updateFollowRecord(FollowRecord record) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final updated = record.copyWith(updatedAt: DateTime.now());

    if (record.customerId != null && _customerRecords.containsKey(record.customerId)) {
      final index = _customerRecords[record.customerId]!.indexWhere((r) => r.id == record.id);
      if (index != -1) _customerRecords[record.customerId]![index] = updated;
    }
    if (record.clueId != null && _clueRecords.containsKey(record.clueId)) {
      final index = _clueRecords[record.clueId]!.indexWhere((r) => r.id == record.id);
      if (index != -1) _clueRecords[record.clueId]![index] = updated;
    }

    return updated;
  }

  @override
  Future<void> deleteFollowRecord(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    for (final records in _customerRecords.values) {
      records.removeWhere((r) => r.id == id);
    }
    for (final records in _clueRecords.values) {
      records.removeWhere((r) => r.id == id);
    }
  }
}
