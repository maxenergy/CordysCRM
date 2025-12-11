/// 商机实体
class Opportunity {
  final String id;
  final String name;
  final String? customerId;
  final String? customerName;
  final double? amount;
  final String stage;
  final int? probability;
  final DateTime? expectedCloseDate;
  final String? owner;
  final String? remark;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Opportunity({
    required this.id,
    required this.name,
    this.customerId,
    this.customerName,
    this.amount,
    required this.stage,
    this.probability,
    this.expectedCloseDate,
    this.owner,
    this.remark,
    this.createdAt,
    this.updatedAt,
  });

  /// 商机阶段
  static const stageInitial = 'initial';       // 初步接触
  static const stageQualified = 'qualified';   // 需求确认
  static const stageProposal = 'proposal';     // 方案报价
  static const stageNegotiation = 'negotiation'; // 商务谈判
  static const stageWon = 'won';               // 赢单
  static const stageLost = 'lost';             // 输单

  /// 获取阶段显示文本
  String get stageText {
    switch (stage) {
      case stageInitial:
        return '初步接触';
      case stageQualified:
        return '需求确认';
      case stageProposal:
        return '方案报价';
      case stageNegotiation:
        return '商务谈判';
      case stageWon:
        return '赢单';
      case stageLost:
        return '输单';
      default:
        return stage;
    }
  }

  /// 获取阶段索引（用于进度显示）
  int get stageIndex {
    switch (stage) {
      case stageInitial:
        return 0;
      case stageQualified:
        return 1;
      case stageProposal:
        return 2;
      case stageNegotiation:
        return 3;
      case stageWon:
        return 4;
      case stageLost:
        return -1;
      default:
        return 0;
    }
  }

  /// 是否可以推进阶段
  bool get canAdvance => stage != stageWon && stage != stageLost;

  /// 是否已结束
  bool get isClosed => stage == stageWon || stage == stageLost;

  Opportunity copyWith({
    String? id,
    String? name,
    String? customerId,
    String? customerName,
    double? amount,
    String? stage,
    int? probability,
    DateTime? expectedCloseDate,
    String? owner,
    String? remark,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Opportunity(
      id: id ?? this.id,
      name: name ?? this.name,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      amount: amount ?? this.amount,
      stage: stage ?? this.stage,
      probability: probability ?? this.probability,
      expectedCloseDate: expectedCloseDate ?? this.expectedCloseDate,
      owner: owner ?? this.owner,
      remark: remark ?? this.remark,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
