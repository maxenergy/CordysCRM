import '../entities/opportunity.dart';

/// 商机筛选条件
class OpportunityQuery {
  final String? search;
  final String? stage;
  final String? owner;
  final DateTime? startDate;
  final DateTime? endDate;

  const OpportunityQuery({
    this.search,
    this.stage,
    this.owner,
    this.startDate,
    this.endDate,
  });
}

/// 分页响应
class PagedOpportunityResponse {
  final List<Opportunity> items;
  final int total;
  final bool hasMore;

  const PagedOpportunityResponse({
    required this.items,
    required this.total,
    required this.hasMore,
  });
}

/// 商机仓库接口
abstract class OpportunityRepository {
  /// 获取商机列表（分页）
  Future<PagedOpportunityResponse> getOpportunities({
    required int page,
    required int pageSize,
    OpportunityQuery? query,
  });

  /// 根据 ID 获取商机
  Future<Opportunity?> getOpportunityById(String id);

  /// 创建商机
  Future<Opportunity> createOpportunity(Opportunity opportunity);

  /// 更新商机
  Future<Opportunity> updateOpportunity(Opportunity opportunity);

  /// 删除商机
  Future<void> deleteOpportunity(String id);

  /// 推进商机阶段
  Future<Opportunity> advanceStage(String opportunityId, String newStage);
}
