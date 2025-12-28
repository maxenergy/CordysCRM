#!/bin/bash
# Claude-Mem 诊断脚本
# 用于诊断 Claude-Mem 无法捕获观察的问题

set -e

echo "=== Claude-Mem 诊断工具 ==="
echo ""

# 1. 检查 Worker 状态
echo "1. 检查 Worker 服务状态..."
if curl -s http://localhost:37777/api/readiness | grep -q "ready"; then
    echo "✓ Worker 服务运行正常"
else
    echo "✗ Worker 服务未运行或无响应"
    exit 1
fi
echo ""

# 2. 检查数据库
echo "2. 检查数据库状态..."
DB_PATH=~/.claude-mem/claude-mem.db

if [ ! -f "$DB_PATH" ]; then
    echo "✗ 数据库文件不存在: $DB_PATH"
    exit 1
fi

OBS_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM observations;")
SESSION_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM sdk_sessions;")

echo "   - 观察记录数: $OBS_COUNT"
echo "   - 会话数: $SESSION_COUNT"

if [ "$OBS_COUNT" -eq 0 ]; then
    echo "✗ 警告: 没有观察记录被捕获"
else
    echo "✓ 数据库包含观察记录"
fi
echo ""

# 3. 检查 Hooks
echo "3. 检查 Kiro Hooks..."
if [ -d ".kiro/hooks" ]; then
    HOOK_COUNT=$(find .kiro/hooks -name "*.js" | wc -l)
    echo "   - 找到 $HOOK_COUNT 个 hook 文件"
    if [ "$HOOK_COUNT" -gt 0 ]; then
        echo "✓ Hooks 已安装"
        find .kiro/hooks -name "*.js" -exec basename {} \;
    else
        echo "✗ 警告: 没有找到 hook 文件"
    fi
else
    echo "✗ .kiro/hooks 目录不存在"
fi
echo ""

# 4. 检查 Chroma
echo "4. 检查 Chroma 向量数据库..."
CHROMA_DIR=~/.claude-mem/chroma

if [ -d "$CHROMA_DIR" ]; then
    CHROMA_SIZE=$(du -sh "$CHROMA_DIR" | cut -f1)
    echo "   - Chroma 目录大小: $CHROMA_SIZE"
    
    # 检查最近的错误日志
    if tail -100 ~/.claude-mem/logs/worker-$(date +%Y-%m-%d).log | grep -q "CHROMA.*Error"; then
        echo "✗ 警告: Chroma 有错误日志"
        echo "   最近的 Chroma 错误:"
        tail -100 ~/.claude-mem/logs/worker-$(date +%Y-%m-%d).log | grep "CHROMA.*Error" | tail -3
    else
        echo "✓ Chroma 运行正常"
    fi
else
    echo "✗ Chroma 目录不存在"
fi
echo ""

# 5. 检查配置
echo "5. 检查配置..."
if [ -f ".kiro/settings/claude-mem.json" ]; then
    echo "✓ 配置文件存在"
    echo "   当前配置:"
    cat .kiro/settings/claude-mem.json | python3 -m json.tool
else
    echo "✗ 配置文件不存在"
fi
echo ""

# 6. 建议
echo "=== 诊断结果和建议 ==="
echo ""

if [ "$OBS_COUNT" -eq 0 ]; then
    echo "问题: 没有观察记录被捕获"
    echo ""
    echo "可能的原因:"
    echo "1. Hooks 未正确触发"
    echo "2. Worker 服务与 Kiro IDE 集成有问题"
    echo "3. 会话未正确初始化"
    echo ""
    echo "建议的修复步骤:"
    echo "1. 重启 Worker 服务: ./scripts/restart_claude_mem.sh"
    echo "2. 重新加载 Kiro IDE 窗口"
    echo "3. 执行一些文件操作（读取、搜索等）"
    echo "4. 再次运行此诊断脚本检查是否有新的观察记录"
fi

if tail -100 ~/.claude-mem/logs/worker-$(date +%Y-%m-%d).log | grep -q "CHROMA.*Error"; then
    echo ""
    echo "问题: Chroma 向量数据库有错误"
    echo ""
    echo "建议的修复步骤:"
    echo "1. 备份现有数据: cp -r ~/.claude-mem ~/.claude-mem.backup"
    echo "2. 重建 Chroma: ./scripts/fix_claude_mem_chroma.sh"
    echo "3. 重启 Worker: ./scripts/restart_claude_mem.sh"
fi

echo ""
echo "=== 诊断完成 ==="
