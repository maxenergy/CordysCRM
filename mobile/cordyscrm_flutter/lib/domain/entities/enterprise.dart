/// 企业实体类
///
/// 表示从爱企查获取的企业信息
class Enterprise {
  const Enterprise({
    required this.id,
    required this.name,
    this.creditCode = '',
    this.legalPerson = '',
    this.registeredCapital = '',
    this.establishDate = '',
    this.status = '',
    this.address = '',
    this.industry = '',
    this.businessScope = '',
    this.phone = '',
    this.email = '',
    this.website = '',
    this.source = '',
  });

  /// 企业 ID（爱企查 ID）
  final String id;

  /// 企业名称
  final String name;

  /// 统一社会信用代码
  final String creditCode;

  /// 法定代表人
  final String legalPerson;

  /// 注册资本
  final String registeredCapital;

  /// 成立日期
  final String establishDate;

  /// 经营状态（存续、注销、吊销等）
  final String status;

  /// 注册地址
  final String address;

  /// 所属行业
  final String industry;

  /// 经营范围
  final String businessScope;

  /// 联系电话
  final String phone;

  /// 电子邮箱
  final String email;

  /// 官网
  final String website;

  /// 数据来源: local(本地数据库) 或 iqicha(爱企查)
  final String source;

  /// 是否为存续状态
  bool get isActive => status == '存续' || status == '在业';

  /// 是否来自本地数据库
  bool get isLocal => source == 'local';

  /// 是否来自爱企查
  bool get isFromIqicha => source == 'iqicha';

  /// 是否来自企查查
  bool get isFromQcc => source == 'qcc';

  /// 是否需要从详情页获取完整信息
  /// 
  /// 搜索结果列表页只有基本信息，详细信息（地址、行业、经营范围、电话等）
  /// 需要进入详情页才能获取。
  bool get needsDetailFetch {
    // 只有企查查来源的数据才需要检查
    if (!isFromQcc) return false;
    
    // 如果关键详细字段都为空，说明需要从详情页获取
    return address.isEmpty && 
           industry.isEmpty && 
           businessScope.isEmpty &&
           phone.isEmpty &&
           email.isEmpty;
  }

  /// 复制并修改
  Enterprise copyWith({
    String? id,
    String? name,
    String? creditCode,
    String? legalPerson,
    String? registeredCapital,
    String? establishDate,
    String? status,
    String? address,
    String? industry,
    String? businessScope,
    String? phone,
    String? email,
    String? website,
    String? source,
  }) {
    return Enterprise(
      id: id ?? this.id,
      name: name ?? this.name,
      creditCode: creditCode ?? this.creditCode,
      legalPerson: legalPerson ?? this.legalPerson,
      registeredCapital: registeredCapital ?? this.registeredCapital,
      establishDate: establishDate ?? this.establishDate,
      status: status ?? this.status,
      address: address ?? this.address,
      industry: industry ?? this.industry,
      businessScope: businessScope ?? this.businessScope,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      source: source ?? this.source,
    );
  }

  /// 从 JSON 解析
  factory Enterprise.fromJson(Map<String, dynamic> json) {
    return Enterprise(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      creditCode: json['creditCode'] as String? ?? '',
      legalPerson: json['legalPerson'] as String? ?? '',
      registeredCapital: json['registeredCapital'] as String? ?? '',
      establishDate: json['establishDate'] as String? ?? '',
      status: json['status'] as String? ?? '',
      address: json['address'] as String? ?? '',
      industry: json['industry'] as String? ?? '',
      businessScope: json['businessScope'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      website: json['website'] as String? ?? '',
      source: json['source'] as String? ?? '',
    );
  }

  /// 从后端搜索结果解析（爱企查 API 返回格式）
  factory Enterprise.fromSearchItem(Map<String, dynamic> json) {
    return Enterprise(
      id: json['pid'] as String? ?? '',
      name: json['name'] as String? ?? '',
      creditCode: json['creditCode'] as String? ?? '',
      legalPerson: json['legalPerson'] as String? ?? '',
      registeredCapital: json['registeredCapital'] as String? ?? '',
      establishDate: json['establishDate'] as String? ?? '',
      status: json['status'] as String? ?? '',
      address: json['address'] as String? ?? '',
      industry: json['industry'] as String? ?? '',
      businessScope: json['scope'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      website: json['website'] as String? ?? '',
      source: json['source'] as String? ?? '',
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'creditCode': creditCode,
      'legalPerson': legalPerson,
      'registeredCapital': registeredCapital,
      'establishDate': establishDate,
      'status': status,
      'address': address,
      'industry': industry,
      'businessScope': businessScope,
      'phone': phone,
      'email': email,
      'website': website,
      'source': source,
    };
  }

  @override
  String toString() => 'Enterprise(id: $id, name: $name)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Enterprise && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// 企业导入结果
class EnterpriseImportResult {
  const EnterpriseImportResult({
    required this.status,
    this.customerId,
    this.message,
    this.conflictingCustomer,
  });

  /// 导入状态: success, conflict, error
  final String status;

  /// 导入成功时的客户 ID
  final String? customerId;

  /// 提示信息
  final String? message;

  /// 冲突时的现有客户信息
  final Map<String, dynamic>? conflictingCustomer;

  bool get isSuccess => status == 'success';
  bool get isConflict => status == 'conflict';
  bool get isError => status == 'error';

  factory EnterpriseImportResult.fromJson(Map<String, dynamic> json) {
    return EnterpriseImportResult(
      status: json['status'] as String? ?? 'error',
      customerId: json['customerId'] as String?,
      message: json['message'] as String?,
      conflictingCustomer: json['conflictingCustomer'] as Map<String, dynamic>?,
    );
  }
}

/// 企业搜索结果
class EnterpriseSearchResult {
  const EnterpriseSearchResult({
    required this.success,
    this.items = const [],
    this.total = 0,
    this.message,
  });

  /// 是否成功
  final bool success;

  /// 搜索结果列表
  final List<Enterprise> items;

  /// 总数
  final int total;

  /// 错误信息
  final String? message;

  bool get hasError => !success && message != null;

  factory EnterpriseSearchResult.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List<dynamic>? ?? [];
    return EnterpriseSearchResult(
      success: json['success'] as bool? ?? false,
      items: itemsList.map((e) => Enterprise.fromSearchItem(e as Map<String, dynamic>)).toList(),
      total: json['total'] as int? ?? 0,
      message: json['message'] as String?,
    );
  }

  factory EnterpriseSearchResult.error(String message) {
    return EnterpriseSearchResult(
      success: false,
      message: message,
    );
  }
}
