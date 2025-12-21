import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../../core/network/dio_client.dart';
import '../../domain/entities/customer.dart';
import '../../domain/repositories/customer_repository.dart';

/// 客户仓库实现
/// 
/// 调用后端 API 获取客户数据
class CustomerRepositoryImpl implements CustomerRepository {
  CustomerRepositoryImpl({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  final Dio _dio;
  final _logger = Logger(printer: PrettyPrinter(methodCount: 0));
  static const _basePath = '/account';
  static const _enterprisePath = '/enterprise';

  @override
  Future<PagedResponse<Customer>> getCustomers({
    required int page,
    required int pageSize,
    CustomerQuery? query,
  }) async {
    _logger.d('获取客户列表: page=$page, pageSize=$pageSize, query=$query');

    try {
      // 构建请求体
      final requestBody = <String, dynamic>{
        'current': page,
        'pageSize': pageSize,
        'viewId': 'ALL', // 查看所有数据（需要有对应权限）
      };

      // 添加搜索条件
      if (query != null && query.search != null && query.search!.isNotEmpty) {
        requestBody['combineSearch'] = {
          'searchMode': 'AND',
          'conditions': [
            {
              'name': 'name',
              'operator': 'LIKE',
              'value': query.search,
            }
          ],
        };
      }

      final response = await _dio.post(
        '$_basePath/page',
        data: requestBody,
      );

      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;

        // 处理 ResultHolder 包装格式
        Map<String, dynamic> pageData;
        if (responseData.containsKey('code') && responseData.containsKey('data')) {
          final code = responseData['code'] as int?;
          if (code != null && code != 100200) {
            final message = responseData['message'] as String? ?? '服务器错误 (code: $code)';
            _logger.w('获取客户列表失败: code=$code, message=$message');
            throw Exception(message);
          }
          pageData = responseData['data'] as Map<String, dynamic>? ?? {};
        } else {
          pageData = responseData;
        }

        // 解析分页数据
        final listData = pageData['list'] as List<dynamic>? ?? [];
        final total = pageData['total'] as int? ?? 0;

        final customers = listData.map((item) {
          final map = item as Map<String, dynamic>;
          return _parseCustomer(map);
        }).toList();

        _logger.i('获取客户列表成功: ${customers.length} 条, 总计 $total 条');

        return PagedResponse(
          items: customers,
          total: total,
          page: page,
          pageSize: pageSize,
        );
      }

      throw Exception('获取客户列表失败: ${response.statusCode}');
    } on DioException catch (e) {
      _logger.e('获取客户列表失败: ${e.message}');
      if (e.response?.statusCode == 401) {
        throw Exception('请先登录');
      }
      throw Exception('获取客户列表失败: ${e.message ?? '网络错误'}');
    } catch (e) {
      _logger.e('获取客户列表异常: $e');
      rethrow;
    }
  }

  @override
  Future<Customer?> getCustomerById(String id) async {
    _logger.d('获取客户详情: id=$id');

    try {
      final response = await _dio.get('$_basePath/get/$id');

      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;

        // 处理 ResultHolder 包装格式
        Map<String, dynamic> customerData;
        if (responseData.containsKey('code') && responseData.containsKey('data')) {
          final code = responseData['code'] as int?;
          if (code != null && code != 100200) {
            _logger.w('获取客户详情失败: code=$code');
            return null;
          }
          customerData = responseData['data'] as Map<String, dynamic>? ?? {};
        } else {
          customerData = responseData;
        }

        // 解析客户基本信息
        final customer = _parseCustomer(customerData);
        
        // 尝试获取企业画像
        final enterpriseProfile = await _getEnterpriseProfile(id);
        if (enterpriseProfile != null) {
          return customer.copyWith(enterpriseProfile: enterpriseProfile);
        }
        
        return customer;
      }

      return null;
    } on DioException catch (e) {
      _logger.e('获取客户详情失败: ${e.message}');
      return null;
    } catch (e) {
      _logger.e('获取客户详情异常: $e');
      return null;
    }
  }

  /// 获取企业画像
  Future<EnterpriseProfile?> _getEnterpriseProfile(String customerId) async {
    try {
      final response = await _dio.get('$_enterprisePath/profile/$customerId');
      
      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;
        
        // 处理 ResultHolder 包装格式
        Map<String, dynamic>? profileData;
        if (responseData.containsKey('code') && responseData.containsKey('data')) {
          final code = responseData['code'] as int?;
          if (code != null && code != 100200) {
            _logger.d('客户无企业画像: customerId=$customerId');
            return null;
          }
          profileData = responseData['data'] as Map<String, dynamic>?;
        } else {
          profileData = responseData;
        }
        
        if (profileData != null && profileData.isNotEmpty) {
          _logger.d('获取企业画像成功: customerId=$customerId');
          return EnterpriseProfile.fromJson(profileData);
        }
      }
      
      return null;
    } on DioException catch (e) {
      _logger.d('获取企业画像失败: ${e.message}');
      return null;
    } catch (e) {
      _logger.d('获取企业画像异常: $e');
      return null;
    }
  }

  @override
  Future<Customer> createCustomer(Customer customer) async {
    _logger.d('创建客户: ${customer.name}');

    try {
      final requestBody = _customerToRequest(customer);

      final response = await _dio.post(
        '$_basePath/add',
        data: requestBody,
      );

      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;

        // 处理 ResultHolder 包装格式
        Map<String, dynamic> customerData;
        if (responseData.containsKey('code') && responseData.containsKey('data')) {
          final code = responseData['code'] as int?;
          if (code != null && code != 100200) {
            final message = responseData['message'] as String? ?? '创建客户失败';
            throw Exception(message);
          }
          customerData = responseData['data'] as Map<String, dynamic>? ?? {};
        } else {
          customerData = responseData;
        }

        return _parseCustomer(customerData);
      }

      throw Exception('创建客户失败: ${response.statusCode}');
    } on DioException catch (e) {
      _logger.e('创建客户失败: ${e.message}');
      throw Exception('创建客户失败: ${e.message ?? '网络错误'}');
    }
  }

  @override
  Future<Customer> updateCustomer(Customer customer) async {
    _logger.d('更新客户: ${customer.id}');

    try {
      final requestBody = _customerToRequest(customer);
      requestBody['id'] = customer.id;

      final response = await _dio.post(
        '$_basePath/update',
        data: requestBody,
      );

      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;

        // 处理 ResultHolder 包装格式
        Map<String, dynamic> customerData;
        if (responseData.containsKey('code') && responseData.containsKey('data')) {
          final code = responseData['code'] as int?;
          if (code != null && code != 100200) {
            final message = responseData['message'] as String? ?? '更新客户失败';
            throw Exception(message);
          }
          customerData = responseData['data'] as Map<String, dynamic>? ?? {};
        } else {
          customerData = responseData;
        }

        return _parseCustomer(customerData);
      }

      throw Exception('更新客户失败: ${response.statusCode}');
    } on DioException catch (e) {
      _logger.e('更新客户失败: ${e.message}');
      throw Exception('更新客户失败: ${e.message ?? '网络错误'}');
    }
  }

  @override
  Future<void> deleteCustomer(String id) async {
    _logger.d('删除客户: $id');

    try {
      final response = await _dio.get('$_basePath/delete/$id');

      if (response.statusCode == 200) {
        final responseData = response.data as Map<String, dynamic>?;
        if (responseData != null && responseData.containsKey('code')) {
          final code = responseData['code'] as int?;
          if (code != null && code != 100200) {
            final message = responseData['message'] as String? ?? '删除客户失败';
            throw Exception(message);
          }
        }
        _logger.i('删除客户成功: $id');
        return;
      }

      throw Exception('删除客户失败: ${response.statusCode}');
    } on DioException catch (e) {
      _logger.e('删除客户失败: ${e.message}');
      throw Exception('删除客户失败: ${e.message ?? '网络错误'}');
    }
  }

  @override
  Future<List<Customer>> searchCustomers(String keyword) async {
    _logger.d('搜索客户: $keyword');

    if (keyword.isEmpty) return [];

    try {
      final result = await getCustomers(
        page: 1,
        pageSize: 10,
        query: CustomerQuery(search: keyword),
      );
      return result.items;
    } catch (e) {
      _logger.e('搜索客户失败: $e');
      return [];
    }
  }

  /// 解析后端返回的客户数据
  Customer _parseCustomer(Map<String, dynamic> map) {
    return Customer(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      contactPerson: map['contactPerson']?.toString(),
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      address: map['address']?.toString(),
      status: map['status']?.toString() ?? '潜在客户',
      owner: map['ownerName']?.toString() ?? map['owner']?.toString(),
      industry: map['industry']?.toString(),
      source: map['source']?.toString(),
      createdAt: _parseDateTime(map['createTime']),
      updatedAt: _parseDateTime(map['updateTime']),
    );
  }

  /// 解析时间戳
  DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  /// 将 Customer 转换为请求体
  Map<String, dynamic> _customerToRequest(Customer customer) {
    return {
      'name': customer.name,
      if (customer.contactPerson != null) 'contactPerson': customer.contactPerson,
      if (customer.phone != null) 'phone': customer.phone,
      if (customer.email != null) 'email': customer.email,
      if (customer.address != null) 'address': customer.address,
      if (customer.status != null) 'status': customer.status,
      if (customer.industry != null) 'industry': customer.industry,
      if (customer.source != null) 'source': customer.source,
    };
  }
}
