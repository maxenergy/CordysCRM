import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../domain/entities/customer.dart';
import '../../theme/app_theme.dart';
import 'customer_provider.dart';
import 'widgets/customer_list_item.dart';
import 'widgets/filter_bottom_sheet.dart';

/// 客户列表页面
class CustomerListPage extends ConsumerStatefulWidget {
  const CustomerListPage({super.key});

  @override
  ConsumerState<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends ConsumerState<CustomerListPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// 搜索防抖处理（300ms）
  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final currentQuery = ref.read(customerFilterProvider);
      ref.read(customerFilterProvider.notifier).state = CustomerQuery(
        search: _searchController.text.isEmpty ? null : _searchController.text,
        status: currentQuery.status,
        owner: currentQuery.owner,
        startDate: currentQuery.startDate,
        endDate: currentQuery.endDate,
      );
    });
  }

  /// 打开筛选弹窗
  void _openFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => FilterBottomSheet(
        initialQuery: ref.read(customerFilterProvider),
        onApplyFilter: (newQuery) {
          ref.read(customerFilterProvider.notifier).state = newQuery;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pagingController = ref.watch(customerPagingControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('客户列表'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _buildSearchBar(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => Future.sync(() => pagingController.refresh()),
        child: PagedListView<int, Customer>(
          pagingController: pagingController,
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          builderDelegate: PagedChildBuilderDelegate<Customer>(
            itemBuilder: (context, customer, index) => CustomerListItem(
              customer: customer,
              onTap: () => context.push('/customers/${customer.id}'),
            ),
            firstPageProgressIndicatorBuilder: (_) => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            newPageProgressIndicatorBuilder: (_) => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
            noItemsFoundIndicatorBuilder: (_) => _buildEmptyState(),
            noMoreItemsIndicatorBuilder: (_) => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '没有更多客户了',
                  style: TextStyle(color: AppTheme.textTertiary),
                ),
              ),
            ),
            firstPageErrorIndicatorBuilder: (context) => _buildErrorState(
              pagingController.error,
              () => pagingController.refresh(),
            ),
            newPageErrorIndicatorBuilder: (context) => _buildErrorState(
              pagingController.error,
              () => pagingController.retryLastFailedRequest(),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/customers/new'),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// 搜索栏
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索客户名称、联系人、电话',
                hintStyle: const TextStyle(color: AppTheme.textTertiary),
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppTheme.backgroundColor,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildFilterButton(),
        ],
      ),
    );
  }

  /// 筛选按钮
  Widget _buildFilterButton() {
    final query = ref.watch(customerFilterProvider);
    final hasFilter = query.status != null ||
        query.owner != null ||
        query.startDate != null ||
        query.endDate != null;

    return Stack(
      children: [
        IconButton(
          onPressed: _openFilter,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppTheme.borderColor),
            ),
          ),
          icon: const Icon(Icons.filter_list),
        ),
        if (hasFilter)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  /// 空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: AppTheme.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            '暂无客户数据',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '点击右下角按钮添加新客户',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  /// 错误状态
  Widget _buildErrorState(dynamic error, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppTheme.errorColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            '加载失败',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error?.toString() ?? '未知错误',
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
