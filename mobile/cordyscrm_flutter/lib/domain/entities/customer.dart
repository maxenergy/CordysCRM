import 'package:flutter/foundation.dart';

/// 解析可选日期
DateTime? _parseOptionalDate(dynamic value) {
  if (value == null) return null;
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

/// 企业画像
@immutable
class EnterpriseProfile {
  const EnterpriseProfile({
    this.creditCode,
    this.legalPerson,
    this.regCapital,
    this.regDate,
    this.staffSize,
    this.industryName,
    this.address,
    this.phone,
    this.email,
    this.website,
    this.status,
    this.source,
  });

  final String? creditCode;
  final String? legalPerson;
  final String? regCapital;
  final DateTime? regDate;
  final String? staffSize;
  final String? industryName;
  final String? address;
  final String? phone;
  final String? email;
  final String? website;
  final String? status;
  final String? source;

  factory EnterpriseProfile.fromJson(Map<String, dynamic> json) {
    // 处理注册资本，可能是数字或字符串
    String? regCapitalStr;
    final regCapitalRaw = json['regCapital'] ?? json['reg_capital'];
    if (regCapitalRaw != null) {
      if (regCapitalRaw is num) {
        regCapitalStr = '${regCapitalRaw}万元';
      } else {
        regCapitalStr = regCapitalRaw.toString();
      }
    }

    return EnterpriseProfile(
      creditCode: json['creditCode'] as String? ?? json['credit_code'] as String?,
      legalPerson: json['legalPerson'] as String? ?? json['legal_person'] as String?,
      regCapital: regCapitalStr,
      regDate: _parseOptionalDate(json['regDate'] ?? json['reg_date']),
      staffSize: json['staffSize'] as String? ?? json['staff_size'] as String?,
      industryName: json['industryName'] as String? ?? json['industry_name'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      website: json['website'] as String?,
      status: json['status'] as String?,
      source: json['source'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'creditCode': creditCode,
      'legalPerson': legalPerson,
      'regCapital': regCapital,
      'regDate': regDate?.toIso8601String(),
      'staffSize': staffSize,
      'industryName': industryName,
      'address': address,
      'phone': phone,
      'email': email,
      'website': website,
      'status': status,
      'source': source,
    };
  }

  EnterpriseProfile copyWith({
    String? creditCode,
    String? legalPerson,
    String? regCapital,
    DateTime? regDate,
    String? staffSize,
    String? industryName,
    String? address,
    String? phone,
    String? email,
    String? website,
    String? status,
    String? source,
  }) {
    return EnterpriseProfile(
      creditCode: creditCode ?? this.creditCode,
      legalPerson: legalPerson ?? this.legalPerson,
      regCapital: regCapital ?? this.regCapital,
      regDate: regDate ?? this.regDate,
      staffSize: staffSize ?? this.staffSize,
      industryName: industryName ?? this.industryName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      status: status ?? this.status,
      source: source ?? this.source,
    );
  }
}

/// 客户实体
@immutable
class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    this.owner,
    required this.status,
    this.lastFollowUpAt,
    required this.createdAt,
    required this.updatedAt,
    this.industry,
    this.source,
    this.address,
    this.enterpriseProfile,
  });

  final String id;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? owner;
  final String status;
  final DateTime? lastFollowUpAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? industry;
  final String? source;
  final String? address;
  final EnterpriseProfile? enterpriseProfile;

  /// 从 JSON 创建
  factory Customer.fromJson(Map<String, dynamic> json) {
    final rawProfile = json['enterpriseProfile'] ?? json['enterprise_profile'];
    final profileMap = rawProfile is Map ? rawProfile.cast<String, dynamic>() : null;
    
    return Customer(
      id: json['id'] as String,
      name: json['name'] as String,
      contactPerson: json['contactPerson'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      owner: json['owner'] as String?,
      status: json['status'] as String? ?? 'active',
      lastFollowUpAt: json['lastFollowUpAt'] != null
          ? DateTime.parse(json['lastFollowUpAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      industry: json['industry'] as String?,
      source: json['source'] as String?,
      address: json['address'] as String?,
      enterpriseProfile: profileMap != null ? EnterpriseProfile.fromJson(profileMap) : null,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'contactPerson': contactPerson,
      'phone': phone,
      'email': email,
      'owner': owner,
      'status': status,
      'lastFollowUpAt': lastFollowUpAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'industry': industry,
      'source': source,
      'address': address,
      'enterpriseProfile': enterpriseProfile?.toJson(),
    };
  }

  /// 复制并修改
  Customer copyWith({
    String? id,
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
    String? owner,
    String? status,
    DateTime? lastFollowUpAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? industry,
    String? source,
    String? address,
    EnterpriseProfile? enterpriseProfile,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      owner: owner ?? this.owner,
      status: status ?? this.status,
      lastFollowUpAt: lastFollowUpAt ?? this.lastFollowUpAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      industry: industry ?? this.industry,
      source: source ?? this.source,
      address: address ?? this.address,
      enterpriseProfile: enterpriseProfile ?? this.enterpriseProfile,
    );
  }
}

/// 客户查询参数
@immutable
class CustomerQuery {
  const CustomerQuery({
    this.search,
    this.status,
    this.owner,
    this.startDate,
    this.endDate,
  });

  final String? search;
  final String? status;
  final String? owner;
  final DateTime? startDate;
  final DateTime? endDate;

  CustomerQuery copyWith({
    String? search,
    String? status,
    String? owner,
    DateTime? startDate,
    DateTime? endDate,
    bool clearSearch = false,
    bool clearStatus = false,
    bool clearOwner = false,
    bool clearDates = false,
  }) {
    return CustomerQuery(
      search: clearSearch ? null : (search ?? this.search),
      status: clearStatus ? null : (status ?? this.status),
      owner: clearOwner ? null : (owner ?? this.owner),
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
    );
  }
}

/// 分页响应
@immutable
class PagedResponse<T> {
  const PagedResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => page * pageSize < total;
}
