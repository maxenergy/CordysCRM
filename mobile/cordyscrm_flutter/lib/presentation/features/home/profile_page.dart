import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/enterprise_settings_service.dart';
import '../../../core/utils/enterprise_url_utils.dart';
import '../auth/auth_provider.dart';
import '../enterprise/enterprise_provider.dart';
import '../../routing/app_router.dart';
import '../../widgets/sync_status_indicator.dart';
import '../../../services/sync/sync_provider.dart';
import '../../../services/sync/sync_state.dart';

/// 个人中心页面
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final syncState = ref.watch(syncNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: const [
          SyncStatusIndicator(),
          SizedBox(width: 8),
        ],
      ),
      body: ListView(
        children: [
          // 用户信息卡片
          _buildUserCard(context, authState, theme),
          const SizedBox(height: 16),

          // 功能菜单
          _buildMenuSection(context, ref, theme),
          const SizedBox(height: 16),

          // 同步状态
          _buildSyncSection(context, syncState, ref, theme),
          const SizedBox(height: 16),

          // 退出登录
          _buildLogoutButton(context, ref, theme),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildUserCard(
    BuildContext context,
    AuthState authState,
    ThemeData theme,
  ) {
    final user = authState.user;
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                (user?.name?.isNotEmpty ?? false)
                    ? user!.name!.substring(0, 1).toUpperCase()
                    : 'U',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.name ?? '未登录',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.username ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                // TODO: 编辑个人信息
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) {
    final dataSourceType = ref.watch(enterpriseDataSourceTypeProvider);
    final dataSourceName = switch (dataSourceType) {
      EnterpriseDataSourceType.qcc => '企查查',
      EnterpriseDataSourceType.iqicha => '爱企查',
      _ => '企查查',
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildMenuItem(
            context,
            icon: Icons.business_outlined,
            title: '企业信息查询',
            subtitle: '当前数据源: $dataSourceName',
            onTap: () => context.push(AppRoutes.enterprise),
          ),
          const Divider(height: 1),
          _buildMenuItem(
            context,
            icon: Icons.swap_horiz_outlined,
            title: '数据源设置',
            subtitle: '切换企查查/爱企查',
            onTap: () => _showDataSourceDialog(context, ref),
          ),
          const Divider(height: 1),
          _buildMenuItem(
            context,
            icon: Icons.notifications_outlined,
            title: '消息通知',
            subtitle: '查看系统消息',
            onTap: () {
              // TODO: 消息通知页面
            },
          ),
          const Divider(height: 1),
          _buildMenuItem(
            context,
            icon: Icons.settings_outlined,
            title: '设置',
            subtitle: '应用设置',
            onTap: () {
              // TODO: 设置页面
            },
          ),
          const Divider(height: 1),
          _buildMenuItem(
            context,
            icon: Icons.info_outline,
            title: '关于',
            subtitle: '版本信息',
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildSyncSection(
    BuildContext context,
    SyncState syncState,
    WidgetRef ref,
    ThemeData theme,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sync,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '数据同步',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '待同步: ${syncState.pendingCount} 条',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '最后同步: ${_formatLastSync(syncState.lastSyncedAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: syncState.isSyncing
                      ? null
                      : () => ref.read(syncNotifierProvider.notifier).triggerSync(),
                  child: syncState.isSyncing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('立即同步'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: FilledButton(
        onPressed: () => _showLogoutConfirmDialog(context, ref),
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.error,
          foregroundColor: theme.colorScheme.onError,
        ),
        child: const Text('退出登录'),
      ),
    );
  }

  String _formatLastSync(DateTime? lastSync) {
    if (lastSync == null) return '从未同步';
    final now = DateTime.now();
    final diff = now.difference(lastSync);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    return '${diff.inDays} 天前';
  }

  void _showLogoutConfirmDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(authProvider.notifier).logout();
              context.go(AppRoutes.login);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'CordysCRM',
      applicationVersion: '1.0.0',
      applicationIcon: const FlutterLogo(size: 48),
      children: const [
        Text('企业客户关系管理系统'),
        SizedBox(height: 8),
        Text('© 2024 Cordys'),
      ],
    );
  }

  void _showDataSourceDialog(BuildContext context, WidgetRef ref) {
    final currentType = ref.read(enterpriseDataSourceTypeProvider);

    showDialog(
      context: context,
      builder: (dialogContext) => _DataSourceDialog(
        currentType: currentType,
        onSelected: (value) => _onDataSourceChanged(context, ref, value),
      ),
    );
  }

  void _onDataSourceChanged(
    BuildContext context,
    WidgetRef ref,
    EnterpriseDataSourceType value,
  ) {
    // 更新 Provider 状态
    ref.read(enterpriseDataSourceTypeProvider.notifier).state = value;

    // 持久化到本地存储
    ref.read(enterpriseSettingsServiceProvider).setDataSourceType(value);

    // 显示提示
    final name = switch (value) {
      EnterpriseDataSourceType.qcc => '企查查',
      EnterpriseDataSourceType.iqicha => '爱企查',
      _ => '未知',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已切换到 $name'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// 数据源选择对话框
class _DataSourceDialog extends StatefulWidget {
  const _DataSourceDialog({
    required this.currentType,
    required this.onSelected,
  });

  final EnterpriseDataSourceType currentType;
  final ValueChanged<EnterpriseDataSourceType> onSelected;

  @override
  State<_DataSourceDialog> createState() => _DataSourceDialogState();
}

class _DataSourceDialogState extends State<_DataSourceDialog> {
  late EnterpriseDataSourceType _selectedType;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.currentType;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择数据源'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Radio<EnterpriseDataSourceType>(
              value: EnterpriseDataSourceType.qcc,
              groupValue: _selectedType,
              onChanged: _onChanged,
            ),
            title: const Text('企查查'),
            subtitle: const Text('www.qcc.com'),
            onTap: () => _onChanged(EnterpriseDataSourceType.qcc),
          ),
          ListTile(
            leading: Radio<EnterpriseDataSourceType>(
              value: EnterpriseDataSourceType.iqicha,
              groupValue: _selectedType,
              onChanged: _onChanged,
            ),
            title: const Text('爱企查'),
            subtitle: const Text('aiqicha.baidu.com'),
            onTap: () => _onChanged(EnterpriseDataSourceType.iqicha),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }

  void _onChanged(EnterpriseDataSourceType? value) {
    if (value == null) return;
    setState(() => _selectedType = value);
    widget.onSelected(value);
    Navigator.of(context).pop();
  }
}
