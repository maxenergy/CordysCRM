import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../domain/entities/opportunity.dart';
import '../../../domain/repositories/opportunity_repository.dart';
import '../../theme/app_theme.dart';
import 'opportunity_provider.dart';
import 'widgets/opportunity_list_item.dart';
import 'widgets/opportunity_filter_sheet.dart';

/// 商机列表页面
class OpportunityListPage extends ConsumerStatefulWidget {
  const OpportunityListPage({super.key});

  @override
  ConsumerState<OpportunityListPage> createState() => _OpportunityListPageState();
}

class _OpportunityListPageState extends ConsumerState<OpportunityListPage> {
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

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final currentQuery = ref.read(opportunityFilterProvider);
      ref.read(opportunityFilterProvider.notifier).state = OpportunityQuery(
        search: _searchController.text.isEmpty ? null : _searchController.text,
        stage: currentQuery.stage,
        owner: currentQuery.owner,
      );
    });
  }

  void _openFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => OpportunityFilterSheet(
        initialQuery: ref.read(opportunityFilterProvider),
        onApplyFilter: (newQuery) {
          ref.read(opportunityFilterProvider.notifier).state = newQuery;
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final pagingController = ref.watch(opportunityPagingControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('商机列表'),
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
        child: PagedListView<int, Opportunity>(
          pagingController: pagingController,
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          builderDelegate: PagedChildBuilderDelegate<Opportunity>(
            itemBuilder: (context, opportunity, index) => OpportunityListItem(
              opportunity: opportunity,
              onTap: () => context.push('/opportunities/${opportunity.id}'),
            ),
            firstPageProgressIndicatorBuilder: (_) => const Center(
              child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()),
            ),
            newPageProgressIndicatorBuilder: (_) => const Center(
              child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
            ),
            noItemsFoundIndicatorBuilder: (_) => _buildEmptyState(),
            noMoreItemsIndicatorBuilder: (_) => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('没有更多商机了', style: TextStyle(color: AppTheme.textTertiary)),
              ),
            ),
            firstPageErrorIndicatorBuilder: (context) => _buildErrorState(
              pagingController.error,
              () => pagingController.refresh(),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/opportunities/new'),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

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
                hintText: '搜索商机名称、客户',
                hintStyle: const TextStyle(color: AppTheme.textTertiary),
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
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

  Widget _buildFilterButton() {
    final query = ref.watch(opportunityFilterProvider);
    final hasFilter = query.stage != null || query.owner != null;

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
              decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.trending_up, size: 64, color: AppTheme.textTertiary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text('暂无商机数据', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          const Text('点击右下角按钮添加新商机', style: TextStyle(fontSize: 14, color: AppTheme.textTertiary)),
        ],
      ),
    );
  }

  Widget _buildErrorState(dynamic error, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text('加载失败', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Text(error?.toString() ?? '未知错误', style: const TextStyle(fontSize: 14, color: AppTheme.textTertiary)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
