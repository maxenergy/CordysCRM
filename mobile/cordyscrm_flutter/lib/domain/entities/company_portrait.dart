/// 企业画像实体类
///
/// 包含 AI 生成的企业分析数据
class CompanyPortrait {
  const CompanyPortrait({
    required this.customerId,
    required this.generatedAt,
    required this.basicInfo,
    this.insights = const [],
    this.risks = const [],
    this.opinions = const [],
  });

  /// 客户 ID
  final String customerId;

  /// 生成时间
  final DateTime generatedAt;

  /// 基本信息
  final PortraitBasicInfo basicInfo;

  /// 商机洞察列表
  final List<BusinessInsight> insights;

  /// 风险提示列表
  final List<RiskAlert> risks;

  /// 舆情信息列表
  final List<PublicOpinion> opinions;

  factory CompanyPortrait.fromJson(Map<String, dynamic> json) {
    return CompanyPortrait(
      customerId: json['customerId'] as String? ?? '',
      generatedAt: json['generatedAt'] != null
          ? DateTime.parse(json['generatedAt'] as String)
          : DateTime.now(),
      basicInfo: json['basicInfo'] != null
          ? PortraitBasicInfo.fromJson(json['basicInfo'] as Map<String, dynamic>)
          : const PortraitBasicInfo(),
      insights: (json['insights'] as List<dynamic>?)
              ?.map((e) => BusinessInsight.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      risks: (json['risks'] as List<dynamic>?)
              ?.map((e) => RiskAlert.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      opinions: (json['opinions'] as List<dynamic>?)
              ?.map((e) => PublicOpinion.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customerId': customerId,
      'generatedAt': generatedAt.toIso8601String(),
      'basicInfo': basicInfo.toJson(),
      'insights': insights.map((e) => e.toJson()).toList(),
      'risks': risks.map((e) => e.toJson()).toList(),
      'opinions': opinions.map((e) => e.toJson()).toList(),
    };
  }
}

/// 画像基本信息
class PortraitBasicInfo {
  const PortraitBasicInfo({
    this.industry = '',
    this.scale = '',
    this.mainProducts = '',
    this.foundedYear = '',
    this.employeeCount = '',
    this.annualRevenue = '',
  });

  /// 所属行业
  final String industry;

  /// 企业规模
  final String scale;

  /// 主营产品
  final String mainProducts;

  /// 成立年份
  final String foundedYear;

  /// 员工人数
  final String employeeCount;

  /// 年营收
  final String annualRevenue;

  factory PortraitBasicInfo.fromJson(Map<String, dynamic> json) {
    return PortraitBasicInfo(
      industry: json['industry'] as String? ?? '',
      scale: json['scale'] as String? ?? '',
      mainProducts: json['mainProducts'] as String? ?? '',
      foundedYear: json['foundedYear'] as String? ?? '',
      employeeCount: json['employeeCount'] as String? ?? '',
      annualRevenue: json['annualRevenue'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'industry': industry,
      'scale': scale,
      'mainProducts': mainProducts,
      'foundedYear': foundedYear,
      'employeeCount': employeeCount,
      'annualRevenue': annualRevenue,
    };
  }
}

/// 商机洞察
class BusinessInsight {
  const BusinessInsight({
    required this.title,
    this.confidence = 0.0,
    this.source = '',
    this.description = '',
  });

  /// 洞察标题
  final String title;

  /// 置信度 (0.0 - 1.0)
  final double confidence;

  /// 来源
  final String source;

  /// 详细描述
  final String description;

  factory BusinessInsight.fromJson(Map<String, dynamic> json) {
    return BusinessInsight(
      title: json['title'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      source: json['source'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'confidence': confidence,
      'source': source,
      'description': description,
    };
  }
}

/// 风险级别
enum RiskLevel {
  high('高'),
  medium('中'),
  low('低');

  const RiskLevel(this.label);
  final String label;

  static RiskLevel fromString(String value) {
    switch (value.toLowerCase()) {
      case 'high':
      case '高':
        return RiskLevel.high;
      case 'medium':
      case '中':
        return RiskLevel.medium;
      case 'low':
      case '低':
      default:
        return RiskLevel.low;
    }
  }
}

/// 风险提示
class RiskAlert {
  const RiskAlert({
    required this.title,
    this.level = RiskLevel.low,
    this.description = '',
    this.category = '',
  });

  /// 风险标题
  final String title;

  /// 风险级别
  final RiskLevel level;

  /// 详细描述
  final String description;

  /// 风险类别
  final String category;

  factory RiskAlert.fromJson(Map<String, dynamic> json) {
    return RiskAlert(
      title: json['title'] as String? ?? '',
      level: RiskLevel.fromString(json['level'] as String? ?? 'low'),
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'level': level.name,
      'description': description,
      'category': category,
    };
  }
}

/// 情感倾向
enum Sentiment {
  positive('正面'),
  neutral('中性'),
  negative('负面');

  const Sentiment(this.label);
  final String label;

  static Sentiment fromString(String value) {
    switch (value.toLowerCase()) {
      case 'positive':
      case '正面':
        return Sentiment.positive;
      case 'negative':
      case '负面':
        return Sentiment.negative;
      case 'neutral':
      case '中性':
      default:
        return Sentiment.neutral;
    }
  }
}

/// 舆情信息
class PublicOpinion {
  const PublicOpinion({
    required this.title,
    this.source = '',
    this.sentiment = Sentiment.neutral,
    this.publishedAt,
    this.url = '',
  });

  /// 标题
  final String title;

  /// 来源
  final String source;

  /// 情感倾向
  final Sentiment sentiment;

  /// 发布时间
  final DateTime? publishedAt;

  /// 链接
  final String url;

  factory PublicOpinion.fromJson(Map<String, dynamic> json) {
    return PublicOpinion(
      title: json['title'] as String? ?? '',
      source: json['source'] as String? ?? '',
      sentiment: Sentiment.fromString(json['sentiment'] as String? ?? 'neutral'),
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'] as String)
          : null,
      url: json['url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'source': source,
      'sentiment': sentiment.name,
      if (publishedAt != null) 'publishedAt': publishedAt!.toIso8601String(),
      'url': url,
    };
  }
}
