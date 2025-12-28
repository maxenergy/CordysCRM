#!/bin/bash
# 项目进度查询脚本
# 用法: ./scripts/query_project_progress.sh

set -e

echo "======================================"
echo "  CordysCRM 项目开发进度查询"
echo "======================================"
echo ""

# 检查 Claude-Mem Worker 服务状态
echo "📊 检查 Claude-Mem 服务状态..."
if curl -s http://127.0.0.1:37777/api/readiness > /dev/null 2>&1; then
    echo "✅ Claude-Mem Worker 服务运行正常"
else
    echo "❌ Claude-Mem Worker 服务未运行"
    echo "   请检查服务状态或重启服务"
fi
echo ""

# 显示项目总体进度
echo "======================================"
echo "📈 项目总体进度"
echo "======================================"
echo ""
echo "已完成的 Spec:"
echo "  1. ✅ AI 成本配置 (ai-cost-configuration)"
echo "  2. ✅ 企业搜索分页 (enterprise-search-pagination)"
echo "  3. ✅ 核心数据完整性 (core-data-integrity)"
echo "  4. ✅ Chrome 扩展弹性抓取 (extension-resilient-scraping)"
echo "  5. ✅ Flutter 桌面适配 (flutter-desktop-adaptation)"
echo "  6. ✅ 企业重新搜索 (enterprise-research)"
echo "  7. ✅ 企查查数据源 (flutter-qichacha-search)"
echo ""
echo "进行中的 Spec:"
echo "  8. 🚧 CRM 移动端企业 AI (crm-mobile-enterprise-ai)"
echo "     - [x] 企业搜索基础功能"
echo "     - [x] AI 画像功能"
echo "     - [x] AI 话术功能"
echo "     - [ ] 移动端集成（待开始）"
echo ""

# 显示最近的任务状态
echo "======================================"
echo "📋 最近的任务状态"
echo "======================================"
echo ""

# 检查各个 spec 的任务完成情况
for spec_dir in .kiro/specs/*/; do
    if [ -f "${spec_dir}tasks.md" ]; then
        spec_name=$(basename "$spec_dir")
        total_tasks=$(grep -c "^\[ \]" "${spec_dir}tasks.md" 2>/dev/null || echo 0)
        completed_tasks=$(grep -c "^\[x\]" "${spec_dir}tasks.md" 2>/dev/null || echo 0)
        
        if [ $((total_tasks + completed_tasks)) -gt 0 ]; then
            echo "📁 $spec_name"
            echo "   完成: $completed_tasks / $((total_tasks + completed_tasks)) 任务"
            
            # 显示进度条
            if [ $((total_tasks + completed_tasks)) -gt 0 ]; then
                progress=$((completed_tasks * 100 / (total_tasks + completed_tasks)))
                echo -n "   进度: ["
                for i in $(seq 1 20); do
                    if [ $((i * 5)) -le $progress ]; then
                        echo -n "="
                    else
                        echo -n " "
                    fi
                done
                echo "] $progress%"
            fi
            echo ""
        fi
    fi
done

# 显示关键文档位置
echo "======================================"
echo "📚 关键文档位置"
echo "======================================"
echo ""
echo "开发状态: memory-bank/development-status.md"
echo "Spec 总结: .kiro/specs/SPEC_CREATION_SUMMARY.md"
echo "查询指南: memory-bank/HOW_TO_QUERY_PROJECT_PROGRESS.md"
echo ""

# 显示 Claude-Mem 查询示例
echo "======================================"
echo "💡 Claude-Mem 查询示例"
echo "======================================"
echo ""
echo "在新会话中，你可以直接询问："
echo ""
echo "  • 上次会话我们做了什么？"
echo "  • 显示这个项目的最近工作"
echo "  • 我们是如何实现企业搜索的？"
echo "  • AI 成本配置功能是怎么实现的？"
echo "  • EnterpriseController.java 做了哪些修改？"
echo "  • 我们是如何修复企业搜索超时的？"
echo ""

# 显示 Web 查看器链接
echo "======================================"
echo "🌐 Web 查看器"
echo "======================================"
echo ""
echo "访问 http://localhost:37777 查看："
echo "  • 实时观察捕获流"
echo "  • 会话摘要和统计"
echo "  • 搜索界面"
echo "  • 工作的可视化时间线"
echo ""

echo "======================================"
echo "✅ 查询完成"
echo "======================================"
