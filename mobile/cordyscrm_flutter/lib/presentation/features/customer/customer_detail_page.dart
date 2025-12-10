import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/customer.dart';
import '../../theme/app_theme.dart';
import 'customer_provider.dart';

/// 客户详情页面
class CustomerDetailPage extends ConsumerWidget {
  const CustomerDetailPage({
    super.key,
    required this.customerId,
  });

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customerDetailProvider(customerId));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('客户详情'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showMoreOptions(context, ref),
          ),
        ],
      ),
      body: customerAsync.when(
        data: (customer) {
          if (customer == null) {
            return const Center(child: Text('客户不存在'));
          }
          return _CustomerDetailContent(customer: customer);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
              const SizedBox(height: 16),
              Text('加载失败: $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(customerDetailProvider(customerId)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: customerAsync.hasValue && customerAsync.value != null
          ? _BottomActionBar(customer: customerAsync.value!)
          : null,
    );
  }

  void _showMoreOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
              title: const Text('删除客户', style: TextStyle(color: AppTheme.errorColor)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除该客户吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final repo = ref.read(customerRepositoryProvider);
              await repo.deleteCustomer(customerId);
              ref.invalidate(customerPagingControllerProvider);
              if (context.mounted) {
                context.pop();
              }
            },
            child: const Text('删除', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }
}

/// 客户详情内容
class _CustomerDetailContent extends StatelessWidget {
  const _CustomerDetailContent({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // 客户信息卡片
            SliverToBoxAdapter(child: _CustomerInfoCard(customer: customer)),
            // AI 画像占位
            const SliverToBoxAdapter(child: _AIProfilePlaceholder()),
            // Tab 栏
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                const TabBar(
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: AppTheme.textSecondary,
                  indicatorColor: AppTheme.primaryColor,
                  tabs: [
                    Tab(text: '基本信息'),
                    Tab(text: '跟进记录'),
                    Tab(text: '商机'),
                    Tab(text: '联系人'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          children: [
            _BasicInfoTab(customer: customer),
            const _PlaceholderTab(title: '跟进记录', icon: Icons.history),
            const _PlaceholderTab(title: '商机', icon: Icons.trending_up),
            const _PlaceholderTab(title: '联系人', icon: Icons.contacts),
          ],
        ),
      ),
    );
  }
}

/// 客户信息卡片
class _CustomerInfoCard extends StatelessWidget {
  const _CustomerInfoCard({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 客户名称和状态
            Row(
              children: [
                Expanded(
                  child: Text(
                    customer.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _StatusChip(status: customer.status),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // 联系信息
            _InfoRow(
              icon: Icons.person_outline,
              label: '联系人',
              value: customer.contactPerson ?? '未设置',
            ),
            _InfoRow(
              icon: Icons.phone_outlined,
              label: '电话',
              value: customer.phone ?? '未设置',
              isPhone: true,
            ),
            _InfoRow(
              icon: Icons.email_outlined,
              label: '邮箱',
              value: customer.email ?? '未设置',
            ),
          ],
        ),
      ),
    );
  }
}

/// AI 画像占位组件
class _AIProfilePlaceholder extends StatelessWidget {
  const _AIProfilePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      color: const Color(0xFFE6F7FF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.psychology_alt, color: AppTheme.primaryColor, size: 28),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI 智能画像',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '基于客户行为与特征生成的智能分析报告',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }
}

/// 基本信息 Tab
class _BasicInfoTab extends StatelessWidget {
  const _BasicInfoTab({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _DetailItem(label: '客户名称', value: customer.name),
              _DetailItem(label: '负责人', value: customer.owner ?? '未分配'),
              _DetailItem(label: '行业', value: customer.industry ?? '未设置'),
              _DetailItem(label: '客户来源', value: customer.source ?? '未设置'),
              _DetailItem(label: '地址', value: customer.address ?? '未设置'),
              _DetailItem(
                label: '创建时间',
                value: DateFormat('yyyy-MM-dd HH:mm').format(customer.createdAt),
              ),
              _DetailItem(
                label: '最后更新',
                value: DateFormat('yyyy-MM-dd HH:mm').format(customer.updatedAt),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 占位 Tab
class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppTheme.textTertiary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            '$title 功能开发中',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// 底部操作栏
class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.dividerColor)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ActionButton(
              icon: Icons.edit_outlined,
              label: '编辑',
              onTap: () => context.push('/customers/edit/${customer.id}'),
            ),
            _ActionButton(
              icon: Icons.add_comment_outlined,
              label: '跟进',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('跟进功能开发中')),
                );
              },
            ),
            _ActionButton(
              icon: Icons.speaker_notes_outlined,
              label: '话术',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('AI 话术功能开发中')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 操作按钮
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: AppTheme.primaryColor),
      label: Text(label, style: const TextStyle(color: AppTheme.primaryColor)),
    );
  }
}

// ==================== 辅助组件 ====================

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusBackgroundColor(status),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '意向客户':
        return AppTheme.warningColor;
      case '成交客户':
        return AppTheme.successColor;
      case '流失客户':
        return AppTheme.errorColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  Color _getStatusBackgroundColor(String status) {
    final color = _getStatusColor(status);
    return color.withValues(alpha: 0.1);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isPhone = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isPhone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textTertiary),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isPhone && value != '未设置'
                    ? AppTheme.primaryColor
                    : AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  const _DetailItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: _tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
