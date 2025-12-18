import 'package:uuid/uuid.dart';

import '../../domain/entities/clue.dart';
import '../../domain/repositories/clue_repository.dart';

/// 线索仓库实现
class ClueRepositoryImpl implements ClueRepository {
  // 模拟数据存储
  final List<Clue> _clues = _generateMockClues();

  @override
  Future<PagedClueResponse> getClues({
    required int page,
    required int pageSize,
    ClueQuery? query,
  }) async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 300));

    var filtered = _clues.toList();

    // 应用筛选条件
    if (query != null) {
      if (query.search != null && query.search!.isNotEmpty) {
        final keyword = query.search!.toLowerCase();
        filtered = filtered.where((c) =>
            c.name.toLowerCase().contains(keyword) ||
            (c.phone?.contains(keyword) ?? false)).toList();
      }
      if (query.status != null && query.status != '全部') {
        filtered = filtered.where((c) => c.statusText == query.status).toList();
      }
      if (query.owner != null && query.owner != '全部') {
        filtered = filtered.where((c) => c.owner == query.owner).toList();
      }
      if (query.source != null && query.source != '全部') {
        filtered = filtered.where((c) => c.source == query.source).toList();
      }
    }

    // 分页
    final start = (page - 1) * pageSize;
    final end = start + pageSize;
    final items = filtered.skip(start).take(pageSize).toList();

    return PagedClueResponse(
      items: items,
      total: filtered.length,
      hasMore: end < filtered.length,
    );
  }


  @override
  Future<Clue?> getClueById(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      return _clues.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Clue> createClue(Clue clue) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final newClue = Clue(
      id: const Uuid().v4(),
      name: clue.name,
      phone: clue.phone,
      email: clue.email,
      source: clue.source,
      status: Clue.statusNew,
      owner: clue.owner,
      remark: clue.remark,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _clues.insert(0, newClue);
    return newClue;
  }

  @override
  Future<Clue> updateClue(Clue clue) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _clues.indexWhere((c) => c.id == clue.id);
    if (index == -1) throw Exception('线索不存在');
    
    final updated = clue.copyWith(updatedAt: DateTime.now());
    _clues[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteClue(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _clues.removeWhere((c) => c.id == id);
  }

  @override
  Future<String> convertToCustomer(String clueId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _clues.indexWhere((c) => c.id == clueId);
    if (index == -1) throw Exception('线索不存在');
    
    final clue = _clues[index];
    if (!clue.canConvert) throw Exception('该线索状态不允许转化');
    
    // 更新线索状态为已转化
    _clues[index] = clue.copyWith(
      status: Clue.statusConverted,
      updatedAt: DateTime.now(),
    );
    
    // 返回模拟的客户ID
    return const Uuid().v4();
  }
}

/// 生成模拟线索数据
/// 注意：已清空模拟数据，线索数据应通过实际业务流程创建
List<Clue> _generateMockClues() {
  // 返回空列表，不再生成模拟数据
  return [];
}
