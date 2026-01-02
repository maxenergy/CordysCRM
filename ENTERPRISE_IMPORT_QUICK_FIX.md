# 企业导入问题快速修复

## 问题症状

- ✗ Flutter 企业批量导入失败
- ✗ 单条导入也失败
- ✗ 错误堆栈不完整，缺少 `Caused by` 部分
- ⚠️ 2/20 成功率（说明部分修复有效）

## 一键修复

```bash
./scripts/fix_enterprise_import.sh
```

这个脚本会自动：
1. ✅ 运行完整诊断
2. ✅ 重新编译后端（确保 Mapper XML 加载）
3. ✅ 修复数据库约束（添加唯一索引）
4. ✅ 重启后端服务
5. ✅ 运行验证测试

**预计时间**：3-5 分钟

## 手动修复（如果一键修复失败）

### 步骤 1：诊断

```bash
./scripts/diagnose_import_error.sh
```

查看输出，找到具体问题。

### 步骤 2：根据问题修复

#### 问题 A：Mapper XML 未加载

```bash
cd backend/crm
mvn clean compile -DskipTests
cd ../..
./scripts/debug_enterprise_import.sh
```

#### 问题 B：数据库约束冲突

```sql
-- 连接数据库
mysql -u root -p123456 cordys_crm

-- 添加唯一索引
ALTER TABLE enterprise_profile 
ADD UNIQUE INDEX uk_credit_code_org (credit_code, organization_id);

-- 修改字段类型
ALTER TABLE enterprise_profile 
MODIFY COLUMN shareholders TEXT,
MODIFY COLUMN executives TEXT,
MODIFY COLUMN risks TEXT;
```

#### 问题 C：后端未重启

```bash
# 停止后端
pkill -f spring-boot

# 重启后端
./scripts/debug_enterprise_import.sh
```

### 步骤 3：测试验证

```bash
# 单条导入测试
./scripts/test_enterprise_import_single.sh

# 查看日志
tail -f logs/enterprise-import-debug.log
```

## 验证成功标志

✅ 测试脚本返回成功（200 状态码）
✅ 后端日志显示：`插入企业档案成功`
✅ 数据库中有新记录
✅ `reg_date` 是日期格式（如 `2021-01-01`）

## 如果还是失败

请提供以下信息：

1. **诊断报告**：
   ```bash
   cat logs/diagnostic_report_*.txt
   ```

2. **完整错误日志**：
   ```bash
   tail -100 logs/enterprise-import-debug.log
   ```

3. **数据库状态**：
   ```bash
   mysql -u root -p123456 cordys_crm < scripts/check_enterprise_constraints.sql
   ```

## 相关文档

- `ENTERPRISE_IMPORT_FIX_GUIDE.md` - 详细修复指南
- `ENTERPRISE_IMPORT_TROUBLESHOOTING.md` - 完整排查指南
- `BATCH_IMPORT_FIX_SUMMARY.md` - 日期格式修复总结

## 常见问题

**Q: 为什么要重新编译？**
A: 确保 Mapper XML 文件被正确加载到 classpath 中。

**Q: 为什么要添加唯一索引？**
A: 防止并发导入时产生重复记录。

**Q: 为什么要改字段类型？**
A: JSON 字段可能超过 VARCHAR 长度限制。

**Q: 修复后还需要做什么？**
A: 在 Flutter 中测试批量导入功能，确保稳定性。
