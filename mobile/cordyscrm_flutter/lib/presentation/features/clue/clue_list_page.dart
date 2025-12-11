import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../domain/entities/clue.dart';
import '../../../domain/repositories/clue_repository.dart';
import '../../theme/app_theme.dart';
import 'clue_provider.dart';
import 'widgets/clue_list_item.dart';
import 'widgets/clue_filter_sheet.dart';

/// 线索列表页面
class ClueListPage extends ConsumerStatefulWidget {
  const ClueListPage({super.key});

  @override
  ConsumerState<ClueListPage> createState() => _ClueListPageState();
}

class _ClueListPageState extends ConsumerState<ClueListPage> {
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
      final currentQuery = ref.read(clueFilterProvider);
      ref.read(clueFilterProvider.notifier).state = ClueQuery(
        search: _searchController.text.isEmpty ? null : _searchController.text,
        status: currentQuery.status,
        owner: currentQuery.owner,
        source: currentQuery.source,
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
      builder: (context) => ClueFilterSheet(
        initialQuery: ref.read(clueFilterProvider),
        onApplyFilter: (newQuery) {
          ref.read(clueFilterProvider.notifier).state = newQuery;
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final pagingController = ref.watch(cluePagingControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('线索列表'),
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
        child: PagedListView<int, Clue>(
          pagingController: pagingController,
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          builderDelegate: PagedChildBuilderDelegate<Clue>(
            itemBuilder: (context, clue, index) => ClueListItem(
              clue: clue,
              onTap: () => context.push('/clues/${clue.id}'),
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
                child: Text('没有更多线索了', style: TextStyle(color: AppTheme.textTertiary)),
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
        onPressed: () => context.push('/clues/new'),
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
                hintText: '搜索线索名称、电话',
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

  Widget _buildFilterButton() {
    final query = ref.watch(clueFilterProvider);
    final hasFilter = query.status != null || query.owner != null || query.source != null;

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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lightbulb_outline, size: 64, color: AppTheme.textTertiary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text('暂无线索数据', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          const Text('点击右下角按钮添加新线索', style: TextStyle(fontSize: 14, color: AppTheme.textTertiary)),
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
