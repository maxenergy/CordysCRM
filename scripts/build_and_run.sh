#!/bin/bash
# 编译前后端并运行 Flutter
# 用法: ./scripts/build_and_run.sh [backend|frontend|flutter|all]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${GREEN}=== CordysCRM 编译运行脚本 ===${NC}"
echo "项目根目录: $PROJECT_ROOT"

# 编译后端
build_backend() {
    echo -e "\n${YELLOW}>>> 编译后端 (Maven)...${NC}"
    cd "$PROJECT_ROOT/backend"
    
    # 跳过测试编译
    mvn clean compile -DskipTests -q
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 后端编译成功${NC}"
    else
        echo -e "${RED}✗ 后端编译失败${NC}"
        exit 1
    fi
}

# 编译前端
build_frontend() {
    echo -e "\n${YELLOW}>>> 编译前端 (pnpm)...${NC}"
    cd "$PROJECT_ROOT/frontend"
    
    # 安装依赖（如果需要）
    if [ ! -d "node_modules" ]; then
        echo "安装依赖..."
        pnpm install
    fi
    
    # 编译 web 包
    echo "编译 web..."
    pnpm --filter @cordys/web build
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 前端编译成功${NC}"
    else
        echo -e "${RED}✗ 前端编译失败${NC}"
        exit 1
    fi
}

# 编译 Chrome 扩展
build_chrome_extension() {
    echo -e "\n${YELLOW}>>> 编译 Chrome 扩展...${NC}"
    cd "$PROJECT_ROOT/frontend/packages/chrome-extension"
    
    # 安装依赖（如果需要）
    if [ ! -d "node_modules" ]; then
        echo "安装依赖..."
        npm install
    fi
    
    npm run build
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Chrome 扩展编译成功${NC}"
    else
        echo -e "${RED}✗ Chrome 扩展编译失败${NC}"
        exit 1
    fi
}

# Flutter 分析和运行
run_flutter() {
    echo -e "\n${YELLOW}>>> Flutter 分析...${NC}"
    cd "$PROJECT_ROOT/mobile/cordyscrm_flutter"
    
    # 获取依赖
    flutter pub get
    
    # 分析代码
    flutter analyze --no-fatal-infos
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Flutter 分析通过${NC}"
    else
        echo -e "${YELLOW}⚠ Flutter 分析有警告，但继续运行${NC}"
    fi
    
    # 检查设备
    echo -e "\n${YELLOW}>>> 检查可用设备...${NC}"
    flutter devices
    
    echo -e "\n${GREEN}Flutter 准备就绪，可以运行:${NC}"
    echo "  flutter run -d <device_id>"
}

# 主逻辑
case "${1:-all}" in
    backend)
        build_backend
        ;;
    frontend)
        build_frontend
        ;;
    chrome)
        build_chrome_extension
        ;;
    flutter)
        run_flutter
        ;;
    all)
        build_backend
        build_frontend
        run_flutter
        ;;
    *)
        echo "用法: $0 [backend|frontend|chrome|flutter|all]"
        exit 1
        ;;
esac

echo -e "\n${GREEN}=== 完成 ===${NC}"
