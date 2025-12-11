import 'package:uuid/uuid.dart';

import '../../domain/entities/opportunity.dart';
import '../../domain/repositories/opportunity_repository.dart';

/// 商机仓库实现
class OpportunityRepositoryImpl implements OpportunityRepository {
  final List<Opportunity> _opportunities = _generateMockOpportunities();

  @override
  Future<PagedOpportunityResponse> getOpportunities({
    required int page,
    required int pageSize,
    OpportunityQuery? query,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    var filtered = _opportunities.toList();

    if (query != null) {
      if (query.search != null && query.search!.isNotEmpty) {
        final keyword = query.search!.toLowerCase();
        filtered = filtered.where((o) =>
            o.name.toLowerCase().contains(keyword) ||
            (o.customerName?.toLowerCase().contains(keyword) ?? false)).toList();
      }
      if (query.stage != null && query.stage != '全部') {
        filtered = filtered.where((o) => o.stageText == query.stage).toList();
      }
      if (query.owner != null && query.owner != '全部') {
        filtered = filtered.where((o) => o.owner == query.owner).toList();
      }
    }

    final start = (page - 1) * pageSize;
    final end = start + pageSize;
    final items = filtered.skip(start).take(pageSize).toList();

    return PagedOpportunityResponse(
      items: items,
      total: filtered.length,
      hasMore: end < filtered.length,
    );
  }

  @override
  Future<Opportunity?> getOpportunityById(String id) async {
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      return _opportunities.firstWhere((o) => o.id == id);
    } catch (_) {
      return null;
    }
  }


  @override
  Future<Opportunity> createOpportunity(Opportunity opportunity) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final newOpp = Opportunity(
      id: const Uuid().v4(),
      name: opportunity.name,
      customerId: opportunity.customerId,
      customerName: opportunity.customerName,
      amount: opportunity.amount,
      stage: Opportunity.stageInitial,
      probability: 10,
      expectedCloseDate: opportunity.expectedCloseDate,
      owner: opportunity.owner,
      remark: opportunity.remark,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _opportunities.insert(0, newOpp);
    return newOpp;
  }

  @override
  Future<Opportunity> updateOpportunity(Opportunity opportunity) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _opportunities.indexWhere((o) => o.id == opportunity.id);
    if (index == -1) throw Exception('商机不存在');
    
    final updated = opportunity.copyWith(updatedAt: DateTime.now());
    _opportunities[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteOpportunity(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _opportunities.removeWhere((o) => o.id == id);
  }

  @override
  Future<Opportunity> advanceStage(String opportunityId, String newStage) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _opportunities.indexWhere((o) => o.id == opportunityId);
    if (index == -1) throw Exception('商机不存在');
    
    final opp = _opportunities[index];
    if (!opp.canAdvance) throw Exception('该商机已结束，无法推进');
    
    final probability = _getProbabilityForStage(newStage);
    final updated = opp.copyWith(
      stage: newStage,
      probability: probability,
      updatedAt: DateTime.now(),
    );
    _opportunities[index] = updated;
    return updated;
  }

  int _getProbabilityForStage(String stage) {
    switch (stage) {
      case Opportunity.stageInitial: return 10;
      case Opportunity.stageQualified: return 30;
      case Opportunity.stageProposal: return 50;
      case Opportunity.stageNegotiation: return 70;
      case Opportunity.stageWon: return 100;
      case Opportunity.stageLost: return 0;
      default: return 10;
    }
  }
}

List<Opportunity> _generateMockOpportunities() {
  final stages = [
    Opportunity.stageInitial,
    Opportunity.stageQualified,
    Opportunity.stageProposal,
    Opportunity.stageNegotiation,
    Opportunity.stageWon,
    Opportunity.stageLost,
  ];
  final owners = ['张三', '李四', '王五', '赵六'];
  final customers = ['阿里巴巴', '腾讯科技', '字节跳动', '华为技术', '小米科技'];
  
  return List.generate(40, (i) {
    final now = DateTime.now();
    final stage = stages[i % stages.length];
    return Opportunity(
      id: 'opp_$i',
      name: '${customers[i % customers.length]}项目${i + 1}',
      customerId: 'cust_$i',
      customerName: customers[i % customers.length],
      amount: (i + 1) * 10000.0,
      stage: stage,
      probability: _getProbability(stage),
      expectedCloseDate: now.add(Duration(days: 30 + i * 7)),
      owner: owners[i % owners.length],
      remark: i % 3 == 0 ? '重点跟进项目' : null,
      createdAt: now.subtract(Duration(days: i * 2)),
      updatedAt: now.subtract(Duration(days: i)),
    );
  });
}

int _getProbability(String stage) {
  switch (stage) {
    case Opportunity.stageInitial: return 10;
    case Opportunity.stageQualified: return 30;
    case Opportunity.stageProposal: return 50;
    case Opportunity.stageNegotiation: return 70;
    case Opportunity.stageWon: return 100;
    case Opportunity.stageLost: return 0;
    default: return 10;
  }
}
