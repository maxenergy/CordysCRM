# Bash 脚本规则

## 核心原则

**所有需要多次执行或测试的 bash 命令必须编写成 .sh 脚本文件**，避免每次都需要用户授权。

## 必须遵守的规则

### 1. 脚本化要求

- **禁止**：直接在终端执行多个分离的 bash 命令
- **必须**：将相关命令整合到一个 .sh 脚本文件中
- **好处**：用户只需授权一次，后续修改脚本内容即可重复执行

### 2. 脚本组织规则

| 场景 | 脚本命名 | 存放位置 |
|------|---------|---------|
| API 测试 | `test_api.sh` | `scripts/` |
| 自动标注 | `auto_label.sh` | `scripts/` |
| 数据导出 | `export_data.sh` | `scripts/` |
| 数据库操作 | `db_ops.sh` | `scripts/` |
| 服务启动 | `start_*.sh` | 项目根目录 |

### 3. 脚本编写规范

```bash
#!/bin/bash
# 脚本描述
# 用法: ./scripts/xxx.sh [参数]

set -e  # 遇错即停

# 配置区域（便于修改）
API_BASE="http://localhost:8000/api/v1"
USERNAME="admin"
PASSWORD="admin123"

# 获取 Token（通用函数）
get_token() {
    curl -s -X POST "$API_BASE/auth/login" \
        -H 'Content-Type: application/json' \
        -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}" \
        | python3 -c "import sys,json; print(json.load(sys.stdin)['accessToken'])"
}

TOKEN=$(get_token)

# 主逻辑
# ...
```

### 4. 相同种类不重复创建

- 同一类型的测试/操作，只维护一个脚本文件
- 需要修改测试内容时，直接编辑现有脚本
- 不同种类的操作才创建新脚本

## 示例

### 错误做法 ❌
```bash
# 第一次执行
curl -s -X POST http://localhost:8000/api/v1/auth/login ...

# 第二次执行（又要授权）
curl -s "http://localhost:8000/api/v1/datasets/4/samples" ...
```

### 正确做法 ✅
```bash
# 创建 scripts/test_api.sh，包含所有相关命令
# 只需授权一次，后续修改脚本内容即可
./scripts/test_api.sh
```

## 脚本目录结构

```
scripts/
├── test_api.sh          # API 测试脚本
├── auto_label.sh        # 自动标注脚本
├── export_data.sh       # 数据导出脚本
└── db_ops.sh            # 数据库操作脚本
```
