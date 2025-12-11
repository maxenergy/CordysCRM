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

  void _initMockData() {
    // 为客户生成模拟跟进记录
    for (var i = 0; i < 10; i++) {
      final customerId = 'cust_$i';
      _customerRecords[customerId] = _generateMockRecords(customerId, null, 3 + i % 5);
    }
    // 为线索生成模拟跟进记录
    for (var i = 0; i < 10; i++) {
      final clueId = 'clue_$i';
      _clueRecords[clueId] = _generateMockRecords(null, clueId, 2 + i % 3);
    }
  }

  List<FollowRecord> _generateMockRecords(String? customerId, String? clueId, int count) {
    final types = [FollowRecord.typePhone, FollowRecord.typeVisit, FollowRecord.typeWechat, FollowRecord.typeEmail];
    final contents = [
      '与客户进行了电话沟通，了解了基本需求，客户对我们的产品表示感兴趣。',
      '拜访客户，详细介绍了产品功能和优势，客户反馈良好。',
      '通过微信发送了产品资料，客户表示会仔细研究。',
      '发送了正式报价邮件，等待客户回复。',
      '跟进上次沟通的问题，客户已经内部讨论，预计下周给出答复。',
    ];
    final owners = ['张三', '李四', '王五'];

    return List.generate(count, (i) {
      final now = DateTime.now();
      return FollowRecord(
        id: const Uuid().v4(),
        customerId: customerId,
        clueId: clueId,
        content: contents[i % contents.length],
        followType: types[i % types.length],
        followAt: now.subtract(Duration(days: i * 2, hours: i * 3)),
        createdBy: owners[i % owners.length],
        createdAt: now.subtract(Duration(days: i * 2)),
        updatedAt: now.subtract(Duration(days: i * 2)),
      );
    });
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
