import '../entities/clue.dart';

/// 线索筛选条件
class ClueQuery {
  final String? search;
  final String? status;
  final String? owner;
  final String? source;
  final DateTime? startDate;
  final DateTime? endDate;

  const ClueQuery({
    this.search,
    this.status,
    this.owner,
    this.source,
    this.startDate,
    this.endDate,
  });
}

/// 分页响应
class PagedClueResponse {
  final List<Clue> items;
  final int total;
  final bool hasMore;

  const PagedClueResponse({
    required this.items,
    required this.total,
    required this.hasMore,
  });
}

/// 线索仓库接口
abstract class ClueRepository {
  /// 获取线索列表（分页）
  Future<PagedClueResponse> getClues({
    required int page,
    required int pageSize,
    ClueQuery? query,
  });

  /// 根据 ID 获取线索
  Future<Clue?> getClueById(String id);

  /// 创建线索
  Future<Clue> createClue(Clue clue);

  /// 更新线索
  Future<Clue> updateClue(Clue clue);

  /// 删除线索
  Future<void> deleteClue(String id);

  /// 转化线索为客户
  Future<String> convertToCustomer(String clueId);
}
