#!/bin/bash
# Claude-Mem MCP 服务诊断脚本 (SQLite3 + FAISS 版本)

echo "=== Claude-Mem 诊断报告 (SQLite3 + FAISS) ==="
echo ""

# 1. 检查 Worker 服务状态
echo "1. Worker 服务状态:"
if curl -s http://127.0.0.1:37777/api/readiness > /dev/null 2>&1; then
    echo "   ✅ Worker 服务运行正常"
    curl -s http://127.0.0.1:37777/api/readiness | jq '.'
else
    echo "   ❌ Worker 服务未响应"
fi
echo ""

# 2. 检查主数据库
echo "2. 主数据库状态:"
if [ -f ~/.claude-mem/claude-mem.db ]; then
    echo "   ✅ 数据库文件存在"
    echo "   大小: $(du -h ~/.claude-mem/claude-mem.db | cut -f1)"
    
    # 检查数据库完整性
    if sqlite3 ~/.claude-mem/claude-mem.db "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then
        echo "   ✅ 数据库完整性正常"
    else
        echo "   ⚠️  数据库可能损坏"
    fi
    
    # 检查数据库内容
    echo "   会话数量: $(sqlite3 ~/.claude-mem/claude-mem.db "SELECT COUNT(*) FROM sessions;" 2>/dev/null || echo "无法查询")"
    echo "   观察数量: $(sqlite3 ~/.claude-mem/claude-mem.db "SELECT COUNT(*) FROM observations;" 2>/dev/null || echo "无法查询")"
    
    # 检查 WAL 文件
    if [ -f ~/.claude-mem/claude-mem.db-wal ]; then
        echo "   ℹ️  WAL 文件存在: $(du -h ~/.claude-mem/claude-mem.db-wal | cut -f1)"
    fi
else
    echo "   ❌ 数据库文件不存在"
fi
echo ""

# 3. 检查向量数据库 (SQLite3)
echo "3. 向量数据库状态 (SQLite3 + FAISS):"
if [ -d ~/.claude-mem/vector-db ]; then
    echo "   ✅ 向量数据库目录存在"
    
    if [ -f ~/.claude-mem/vector-db/chroma.sqlite3 ]; then
        echo "   ✅ Chroma SQLite3 文件存在"
        echo "   大小: $(du -h ~/.claude-mem/vector-db/chroma.sqlite3 | cut -f1)"
        
        # 检查向量数据库完整性
        if sqlite3 ~/.claude-mem/vector-db/chroma.sqlite3 "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then
            echo "   ✅ 向量数据库完整性正常"
        else
            echo "   ⚠️  向量数据库可能损坏"
        fi
        
        # 尝试查询向量数据库表
        echo "   表列表:"
        sqlite3 ~/.claude-mem/vector-db/chroma.sqlite3 ".tables" 2>/dev/null | sed 's/^/      /'
    else
        echo "   ❌ Chroma SQLite3 文件不存在"
    fi
    
    # 检查 FAISS 索引文件
    if ls ~/.claude-mem/vector-db/*.faiss 2>/dev/null | grep -q .; then
        echo "   ✅ FAISS 索引文件存在:"
        ls -lh ~/.claude-mem/vector-db/*.faiss 2>/dev/null | awk '{print "      " $9 " (" $5 ")"}'
    else
        echo "   ℹ️  未找到 FAISS 索引文件（可能使用纯 SQLite3）"
    fi
else
    echo "   ❌ 向量数据库目录不存在"
fi
echo ""

# 4. 检查 Hooks
echo "4. Kiro Hooks 状态:"
if [ -d .kiro/hooks ]; then
    echo "   ✅ Hooks 目录存在"
    echo "   已安装的 hooks:"
    ls -1 .kiro/hooks/*.json 2>/dev/null | xargs -n1 basename | sed 's/^/      /'
else
    echo "   ❌ Hooks 目录不存在"
fi
echo ""

# 5. 检查配置
echo "5. Claude-Mem 配置:"
echo "   MCP 配置 (~/.kiro/settings/mcp.json):"
if [ -f ~/.kiro/settings/mcp.json ]; then
    echo "   ✅ MCP 配置文件存在"
    cat ~/.kiro/settings/mcp.json | jq '.mcpServers["claude-mem"]' 2>/dev/null | sed 's/^/      /'
else
    echo "   ❌ MCP 配置文件不存在"
fi
echo ""

echo "   Claude-Mem 设置 (~/.claude-mem/settings.json):"
if [ -f ~/.claude-mem/settings.json ]; then
    echo "   ✅ 设置文件存在"
    cat ~/.claude-mem/settings.json | jq '.' 2>/dev/null | sed 's/^/      /'
else
    echo "   ❌ 设置文件不存在"
fi
echo ""

# 6. 检查最近的日志
echo "6. 最近的 Worker 日志 (最后 15 行):"
LOG_FILE=~/.claude-mem/logs/worker-$(date +%Y-%m-%d).log
if [ -f "$LOG_FILE" ]; then
    tail -15 "$LOG_FILE" | sed 's/^/   /'
else
    echo "   ❌ 今天的日志文件不存在"
    echo "   可用的日志文件:"
    ls -1t ~/.claude-mem/logs/*.log 2>/dev/null | head -3 | sed 's/^/      /'
fi
echo ""

# 7. 检查进程
echo "7. Worker 进程状态:"
if [ -f ~/.claude-mem/worker.pid ]; then
    PID=$(cat ~/.claude-mem/worker.pid)
    if ps -p $PID > /dev/null 2>&1; then
        echo "   ✅ Worker 进程运行中 (PID: $PID)"
        echo "   进程信息:"
        ps -p $PID -o pid,ppid,cmd,etime,rss | sed 's/^/      /'
    else
        echo "   ⚠️  PID 文件存在但进程不在运行 (PID: $PID)"
    fi
else
    echo "   ❌ PID 文件不存在"
fi
echo ""

# 8. 检查端口占用
echo "8. 端口占用状态:"
if netstat -tuln 2>/dev/null | grep -q ":37777"; then
    echo "   ✅ 端口 37777 已被占用"
    netstat -tulnp 2>/dev/null | grep ":37777" | sed 's/^/      /'
else
    echo "   ❌ 端口 37777 未被占用"
fi
echo ""

# 9. 测试 API 端点
echo "9. API 端点测试:"
if curl -s http://127.0.0.1:37777/api/stats > /dev/null 2>&1; then
    echo "   ✅ Stats 端点可访问"
    curl -s http://127.0.0.1:37777/api/stats | jq '.' | sed 's/^/      /'
else
    echo "   ❌ Stats 端点不可访问"
fi
echo ""

echo "=== 诊断完成 ==="
echo ""
echo "📊 诊断总结:"
echo "   数据库类型: SQLite3 (主数据库) + SQLite3/FAISS (向量数据库)"
echo "   向量存储: ~/.claude-mem/vector-db/chroma.sqlite3"
echo ""
echo "🔧 建议操作:"
if ! curl -s http://127.0.0.1:37777/api/readiness > /dev/null 2>&1; then
    echo "   1. Worker 服务未运行，执行修复脚本: ./scripts/fix_claude_mem_complete.sh"
elif ! [ -f ~/.claude-mem/claude-mem.db ]; then
    echo "   1. 数据库文件不存在，执行修复脚本: ./scripts/fix_claude_mem_complete.sh"
elif ! sqlite3 ~/.claude-mem/claude-mem.db "PRAGMA integrity_check;" 2>/dev/null | grep -q "ok"; then
    echo "   1. 数据库可能损坏，执行修复脚本: ./scripts/fix_claude_mem_complete.sh"
else
    echo "   1. 系统运行正常，可以开始使用"
    echo "   2. 在 Kiro IDE 中执行一些操作测试捕获功能"
    echo "   3. 访问 http://127.0.0.1:37777 查看 Web 界面"
fi
echo ""
