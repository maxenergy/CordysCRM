import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/company_portrait.dart';
import '../ai_provider.dart';

/// AI 画像卡片组件
///
/// 展示 AI 生成的企业画像，包含基本信息、商机洞察、风险提示、舆情信息
class AIProfileCard extends ConsumerWidget {
  const AIProfileCard({
    super.key,
    required this.customerId,
  });

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(portraitProvider(customerId));

    return Card(
      margin: const EdgeInsets.all(16),
      child: state.isLoading
          ? _buildShimmer(context)
          : state.hasData
              ? _buildContent(context, ref, state.portrait!)
              : _buildEmpty(context, ref),
    );
  }

  /// 构建空状态
  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 64,
            color: theme.colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无 AI 画像',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮生成专属企业画像',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              ref.read(portraitProvider(customerId).notifier).generatePortrait();
            },
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('生成 AI 画像'),
          ),
        ],
      ),
    );
  }

  /// 构建 Shimmer 加载效果
  Widget _buildShimmer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题骨架
          _ShimmerBox(width: 120, height: 24),
          const SizedBox(height: 16),
          // TabBar 骨架
          Row(
            children: [
              _ShimmerBox(width: 60, height: 32),
              const SizedBox(width: 8),
              _ShimmerBox(width: 60, height: 32),
              const SizedBox(width: 8),
              _ShimmerBox(width: 60, height: 32),
              const SizedBox(width: 8),
              _ShimmerBox(width: 60, height: 32),
            ],
          ),
          const SizedBox(height: 24),
          // 内容骨架
          _ShimmerBox(width: double.infinity, height: 20),
          const SizedBox(height: 12),
          _ShimmerBox(width: 200, height: 16),
          const SizedBox(height: 16),
          _ShimmerBox(width: double.infinity, height: 20),
          const SizedBox(height: 12),
          _ShimmerBox(width: 180, height: 16),
          const SizedBox(height: 16),
          _ShimmerBox(width: double.infinity, height: 20),
          const SizedBox(height: 12),
          _ShimmerBox(width: 220, height: 16),
        ],
      ),
    );
  }

  /// 构建内容
  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    CompanyPortrait portrait,
  ) {
    return DefaultTabController(
      length: 4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI 精准画像',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    ref
                        .read(portraitProvider(customerId).notifier)
                        .generatePortrait();
                  },
                  tooltip: '刷新画像',
                ),
              ],
            ),
          ),

          // TabBar
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: '基本信息'),
              Tab(text: '商机洞察'),
              Tab(text: '风险提示'),
              Tab(text: '相关舆情'),
            ],
          ),

          // TabBarView
          SizedBox(
            height: 280,
            child: TabBarView(
              children: [
                _BasicInfoTab(info: portrait.basicInfo),
                _InsightsTab(insights: portrait.insights),
                _RisksTab(risks: portrait.risks),
                _OpinionsTab(opinions: portrait.opinions),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer 骨架块
class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// 基本信息 Tab
class _BasicInfoTab extends StatelessWidget {
  const _BasicInfoTab({required this.info});

  final PortraitBasicInfo info;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoRow(label: '所属行业', value: info.industry),
        _InfoRow(label: '企业规模', value: info.scale),
        _InfoRow(label: '主营产品', value: info.mainProducts),
        if (info.foundedYear.isNotEmpty)
          _InfoRow(label: '成立年份', value: info.foundedYear),
        if (info.employeeCount.isNotEmpty)
          _InfoRow(label: '员工人数', value: info.employeeCount),
        if (info.annualRevenue.isNotEmpty)
          _InfoRow(label: '年营收', value: info.annualRevenue),
      ],
    );
  }
}

/// 信息行
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// 商机洞察 Tab
class _InsightsTab extends StatelessWidget {
  const _InsightsTab({required this.insights});

  final List<BusinessInsight> insights;

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return const Center(child: Text('暂无商机洞察'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: insights.length,
      itemBuilder: (context, index) {
        final insight = insights[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: _ConfidenceIndicator(confidence: insight.confidence),
            title: Text(insight.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (insight.description.isNotEmpty)
                  Text(
                    insight.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (insight.source.isNotEmpty)
                  Text(
                    '来源: ${insight.source}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 置信度指示器
class _ConfidenceIndicator extends StatelessWidget {
  const _ConfidenceIndicator({required this.confidence});

  final double confidence;

  @override
  Widget build(BuildContext context) {
    final color = confidence >= 0.7
        ? Colors.green
        : confidence >= 0.4
            ? Colors.orange
            : Colors.grey;

    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: confidence,
            strokeWidth: 3,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(color),
          ),
          Text(
            '${(confidence * 100).toInt()}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 风险提示 Tab
class _RisksTab extends StatelessWidget {
  const _RisksTab({required this.risks});

  final List<RiskAlert> risks;

  @override
  Widget build(BuildContext context) {
    if (risks.isEmpty) {
      return const Center(child: Text('暂无风险提示'));
    }

    // 按级别分组
    final highRisks = risks.where((r) => r.level == RiskLevel.high).toList();
    final mediumRisks = risks.where((r) => r.level == RiskLevel.medium).toList();
    final lowRisks = risks.where((r) => r.level == RiskLevel.low).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (highRisks.isNotEmpty)
          _RiskGroup(title: '高风险', risks: highRisks, color: Colors.red),
        if (mediumRisks.isNotEmpty)
          _RiskGroup(title: '中风险', risks: mediumRisks, color: Colors.orange),
        if (lowRisks.isNotEmpty)
          _RiskGroup(title: '低风险', risks: lowRisks, color: Colors.yellow.shade700),
      ],
    );
  }
}

/// 风险分组
class _RiskGroup extends StatelessWidget {
  const _RiskGroup({
    required this.title,
    required this.risks,
    required this.color,
  });

  final String title;
  final List<RiskAlert> risks;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.warning_amber, color: color, size: 18),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...risks.map((risk) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                title: Text(risk.title),
                subtitle: risk.description.isNotEmpty
                    ? Text(
                        risk.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
              ),
            )),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// 舆情信息 Tab
class _OpinionsTab extends StatelessWidget {
  const _OpinionsTab({required this.opinions});

  final List<PublicOpinion> opinions;

  @override
  Widget build(BuildContext context) {
    if (opinions.isEmpty) {
      return const Center(child: Text('暂无舆情信息'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: opinions.length,
      itemBuilder: (context, index) {
        final opinion = opinions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: _SentimentIcon(sentiment: opinion.sentiment),
            title: Text(opinion.title),
            subtitle: Text(
              '来源: ${opinion.source}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            trailing: Chip(
              label: Text(
                opinion.sentiment.label,
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: _getSentimentColor(opinion.sentiment),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
        );
      },
    );
  }

  Color _getSentimentColor(Sentiment sentiment) {
    switch (sentiment) {
      case Sentiment.positive:
        return Colors.green.shade100;
      case Sentiment.negative:
        return Colors.red.shade100;
      case Sentiment.neutral:
        return Colors.grey.shade200;
    }
  }
}

/// 情感图标
class _SentimentIcon extends StatelessWidget {
  const _SentimentIcon({required this.sentiment});

  final Sentiment sentiment;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (sentiment) {
      case Sentiment.positive:
        icon = Icons.thumb_up;
        color = Colors.green;
        break;
      case Sentiment.negative:
        icon = Icons.thumb_down;
        color = Colors.red;
        break;
      case Sentiment.neutral:
        icon = Icons.remove;
        color = Colors.grey;
        break;
    }

    return CircleAvatar(
      backgroundColor: color.withOpacity(0.1),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
