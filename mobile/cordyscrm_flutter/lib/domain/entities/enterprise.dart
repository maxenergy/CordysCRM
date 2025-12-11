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

  /// 是否为存续状态
  bool get isActive => status == '存续' || status == '在业';

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
