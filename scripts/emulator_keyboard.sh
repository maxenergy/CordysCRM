#!/bin/bash
set -e

DEVICE="emulator-5554"

case "$1" in
    enable)
        echo "启用软键盘显示（即使有硬件键盘）..."
        adb -s $DEVICE shell settings put secure show_ime_with_hard_keyboard 1
        echo "设置完成。请重新点击输入框测试。"
        ;;
    disable)
        echo "禁用软键盘显示..."
        adb -s $DEVICE shell settings put secure show_ime_with_hard_keyboard 0
        ;;
    status)
        echo "当前输入法设置："
        echo "  默认输入法: $(adb -s $DEVICE shell settings get secure default_input_method)"
        echo "  硬键盘时显示软键盘: $(adb -s $DEVICE shell settings get secure show_ime_with_hard_keyboard)"
        echo ""
        echo "已启用的输入法："
        adb -s $DEVICE shell ime list -s
        ;;
    show)
        echo "尝试显示软键盘..."
        adb -s $DEVICE shell am broadcast -a android.intent.action.SHOW_INPUT_METHOD_PICKER
        ;;
    input)
        if [ -z "$2" ]; then
            echo "用法: $0 input <文本>"
            exit 1
        fi
        echo "输入文本: $2"
        adb -s $DEVICE shell input text "$2"
        ;;
    chinese)
        echo "安装中文输入法..."
        echo "注意：模拟器默认不支持中文输入，建议使用英文搜索或通过 adb 输入"
        ;;
    *)
        echo "用法: $0 {enable|disable|status|show|input <text>}"
        echo ""
        echo "命令说明："
        echo "  enable  - 启用软键盘（即使有硬件键盘）"
        echo "  disable - 禁用软键盘"
        echo "  status  - 查看当前输入法状态"
        echo "  show    - 显示输入法选择器"
        echo "  input   - 通过 adb 输入文本"
        ;;
esac
