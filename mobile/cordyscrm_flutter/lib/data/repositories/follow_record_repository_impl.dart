import 'dart:io';
import 'package:flutter/foundation.dart';
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

  @override
  Future<FollowRecord> createFollowRecordWithMedia(
    FollowRecord record, {
    List<dynamic>? images,
    dynamic audio,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    // 模拟上传图片并获取 URL
    List<String>? imageUrls;
    if (images != null && images.isNotEmpty) {
      imageUrls = [];
      for (int i = 0; i < images.length; i++) {
        final file = images[i] as File;
        // 模拟上传，实际应调用后端 API
        debugPrint('[FollowRecordRepository] 上传图片: ${file.path}');
        // 生成模拟 URL
        imageUrls.add('https://example.com/uploads/images/${const Uuid().v4()}.jpg');
      }
    }

    // 模拟上传音频并获取 URL
    String? audioUrl;
    if (audio != null) {
      final file = audio as File;
      debugPrint('[FollowRecordRepository] 上传音频: ${file.path}');
      // 生成模拟 URL
      audioUrl = 'https://example.com/uploads/audio/${const Uuid().v4()}.m4a';
    }

    // 创建带媒体 URL 的记录
    final recordWithMedia = record.copyWith(
      images: imageUrls,
      audioUrl: audioUrl,
    );

    return createFollowRecord(recordWithMedia);
  }
}
