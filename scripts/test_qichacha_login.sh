#!/bin/bash

# =============================================================================
# CordysCRM Flutter - 企查查登录自动化测试脚本
# =============================================================================
# 
# 功能：自动化测试企查查 WebView 登录流程
# 设备：通过 USB ADB 连接的 Android 手机
# 分辨率：1080x2400
#
# 使用方法：
#   chmod +x scripts/test_qichacha_login.sh
#   ./scripts/test_qichacha_login.sh
#
# =============================================================================

set -e

# --- 配置 ---
PACKAGE_NAME="cn.cordys.cordyscrm_flutter"
ACTIVITY_NAME="cn.cordys.cordyscrm_flutter.MainActivity"
PHONE_NUMBER="13902213704"
BACKEND_IP="192.168.31.22"
BACKEND_PORT="8081"

# 屏幕分辨率 1080x2400
SCREEN_WIDTH=1080
SCREEN_HEIGHT=2400

# --- 坐标配置 (基于 UI dump) ---
# "打开 企查查" 按钮中心点
X_QCC_BUTTON=$((936 + (1080 - 936) / 2))  # 1008
Y_QCC_BUTTON=$((119 + (263 - 119) / 2))   # 191

# 搜索输入框中心点
X_SEARCH_INPUT=$((48 + (1032 - 48) / 2))  # 540
Y_SEARCH_INPUT=$((323 + (476 - 323) / 2)) # 400

# --- 颜色输出 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# --- 工具函数 ---
take_screenshot() {
    local name=$1
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local filename="screenshot_${name}_${timestamp}.png"
    adb shell screencap -p /sdcard/screen.png
    adb pull /sdcard/screen.png "scripts/screenshots/${filename}" 2>/dev/null || true
    log_info "Screenshot saved: scripts/screenshots/${filename}"
}

wait_for_app() {
    local max_wait=10
    local count=0
    while [ $count -lt $max_wait ]; do
        local current=$(adb shell dumpsys window | grep -E 'mCurrentFocus' | grep -o "$PACKAGE_NAME" || true)
        if [ -n "$current" ]; then
            return 0
        fi
        sleep 1
        count=$((count + 1))
    done
    return 1
}

tap() {
    local x=$1
    local y=$2
    local desc=$3
    log_info "Tap ($x, $y) - $desc"
    adb shell input tap $x $y
}

input_text() {
    local text=$1
    log_info "Input text: $text"
    adb shell input text "$text"
}

swipe() {
    local x1=$1
    local y1=$2
    local x2=$3
    local y2=$4
    local duration=${5:-300}
    log_info "Swipe from ($x1, $y1) to ($x2, $y2)"
    adb shell input swipe $x1 $y1 $x2 $y2 $duration
}

press_back() {
    log_info "Press BACK key"
    adb shell input keyevent KEYCODE_BACK
}

press_enter() {
    log_info "Press ENTER key"
    adb shell input keyevent KEYCODE_ENTER
}

# --- 创建截图目录 ---
mkdir -p scripts/screenshots

# =============================================================================
# 测试步骤
# =============================================================================

echo ""
echo "=============================================="
echo "  CordysCRM 企查查登录自动化测试"
echo "=============================================="
echo ""

# Step 0: 检查设备连接
log_info "Step 0: 检查设备连接..."
DEVICE=$(adb devices | grep -v "List" | grep "device" | head -1 | awk '{print $1}')
if [ -z "$DEVICE" ]; then
    log_error "未检测到 ADB 设备，请确保手机已连接并开启 USB 调试"
    exit 1
fi
log_success "设备已连接: $DEVICE"

# Step 1: 强制停止应用
log_info "Step 1: 强制停止应用..."
adb shell am force-stop $PACKAGE_NAME
sleep 1
log_success "应用已停止"

# Step 2: 启动应用
log_info "Step 2: 启动应用..."
adb shell am start -n "$PACKAGE_NAME/$ACTIVITY_NAME"
sleep 3

if wait_for_app; then
    log_success "应用已启动"
else
    log_error "应用启动超时"
    exit 1
fi

take_screenshot "01_app_launched"

# Step 3: 点击 "打开 企查查" 按钮
log_info "Step 3: 点击 '打开 企查查' 按钮..."
sleep 2
tap $X_QCC_BUTTON $Y_QCC_BUTTON "打开企查查"
sleep 5  # 等待 WebView 加载

take_screenshot "02_qcc_webview_loading"

# Step 4: 等待企查查页面加载
log_info "Step 4: 等待企查查页面加载..."
sleep 5

take_screenshot "03_qcc_page_loaded"

# Step 5: 检查是否需要登录
log_info "Step 5: 检查登录状态..."
# 企查查登录页面通常有"登录"或"手机号"等文字
# 由于 WebView 内部无法通过 uiautomator 获取，我们需要通过视觉或固定坐标操作

# 尝试点击登录入口（通常在右上角或页面中央）
# 企查查首页右上角登录按钮大约位置
X_LOGIN_ENTRY=$((SCREEN_WIDTH - 100))
Y_LOGIN_ENTRY=200

log_info "Step 6: 尝试点击登录入口..."
tap $X_LOGIN_ENTRY $Y_LOGIN_ENTRY "登录入口"
sleep 3

take_screenshot "04_login_page"

# =============================================================================
# 手动操作阶段
# =============================================================================
echo ""
echo "=============================================="
echo "  需要手动操作"
echo "=============================================="
echo ""
log_warn "请在手机上完成以下步骤："
echo ""
echo "  1. 在企查查页面中找到并点击 '登录' 入口"
echo "  2. 选择手机号登录方式"
echo "  3. 输入手机号: $PHONE_NUMBER"
echo "  4. 获取并输入短信验证码"
echo "  5. 完成登录"
echo ""
log_info "登录成功后，按 Enter 继续自动化测试..."
read -p ""

take_screenshot "05_after_manual_login"

# Step 9: 验证登录成功
log_info "Step 9: 验证登录状态..."
sleep 2
take_screenshot "07_after_login"

# Step 10: 测试企业搜索
log_info "Step 10: 测试企业搜索功能..."
# 返回到搜索页面
press_back
sleep 2

# 在企查查搜索框中输入测试企业名称
X_QCC_SEARCH=$((SCREEN_WIDTH / 2))
Y_QCC_SEARCH=200

tap $X_QCC_SEARCH $Y_QCC_SEARCH "企查查搜索框"
sleep 1

input_text "alibaba"
sleep 1
press_enter
sleep 3

take_screenshot "08_search_result"

# Step 11: 点击搜索结果
log_info "Step 11: 点击搜索结果..."
# 第一个搜索结果通常在搜索框下方
X_FIRST_RESULT=$((SCREEN_WIDTH / 2))
Y_FIRST_RESULT=500

tap $X_FIRST_RESULT $Y_FIRST_RESULT "第一个搜索结果"
sleep 5

take_screenshot "09_company_detail"

# Step 12: 测试导入 CRM 功能
log_info "Step 12: 查找导入 CRM 按钮..."
# 导入按钮通常在页面右下角（我们注入的浮动按钮）
X_IMPORT_BTN=$((SCREEN_WIDTH - 100))
Y_IMPORT_BTN=$((SCREEN_HEIGHT - 200))

take_screenshot "10_before_import"

log_info "点击导入 CRM 按钮..."
tap $X_IMPORT_BTN $Y_IMPORT_BTN "导入CRM"
sleep 3

take_screenshot "11_after_import"

echo ""
echo "=============================================="
echo "  测试完成"
echo "=============================================="
echo ""
log_success "自动化测试流程已完成！"
log_info "请检查 scripts/screenshots/ 目录中的截图验证测试结果"
echo ""
