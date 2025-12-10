import 'package:flutter/foundation.dart';

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

  /// 从 JSON 创建
  factory Customer.fromJson(Map<String, dynamic> json) {
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
