# CordysCRM 问题修复快速开始指南

**目标**: 快速开始修复 CordysCRM 项目中识别出的关键问题  
**前置条件**: 已阅读 `ANALYSIS_EXECUTIVE_SUMMARY.md`

---

## 🚀 立即开始（5 分钟）

### Step 1: 查看分析报告
```bash
# 查看执行摘要
cat ANALYSIS_EXECUTIVE_SUMMARY.md

# 查看完整分析
cat PROJECT_COMPREHENSIVE_ANALYSIS.md

# 查看改进路线图
cat PROJECT_IMPROVEMENT_ROADMAP.md
```

### Step 2: 选择要修复的问题

**推荐顺序**（从易到难）:

1. ✅ **企业搜索分页** (P1) - 3 人日，低风险
2. ✅ **同步状态自愈** (P0) - 2 人日，中风险
3. ✅ **企业去重规范化** (P0) - 3 人日，中风险
4. ✅ **AI 成本配置** (P1) - 5 人日，中风险

### Step 3: 查看对应的 Spec

```bash
# 查看企业搜索分页 Spec
cat .kiro/specs/enterprise-search-pagination/requirements.md
cat .kiro/specs/enterprise-search-pagination/design.md
cat .kiro/specs/enterprise-search-pagination/tasks.md

# 查看核心数据完整性 Spec
cat .kiro/specs/core-data-integrity/requirements.md
cat .kiro/specs/core-data-integrity/design.md
cat .kiro/specs/core-data-integrity/tasks.md
```

---

## 📋 任务 1: 企业搜索分页优化（推荐首选）

### 为什么选这个？
- ✅ 修复数据可访问性 bug
- ✅ 相对低风险（SQL 变更）
- ✅ 快速提升用户满意度
- ✅ 工作量小（3 人日）

### 快速实施步骤

#### Phase 1: Mapper 层分页（1 人日）

**文件**: `backend/crm/src/main/java/cn/cordys/crm/integration/mapper/ExtEnterpriseProfileMapper.xml`

**当前问题**:
```xml
<!-- 硬编码 LIMIT 50 -->
<select id="searchByCompanyName" resultType="EnterpriseProfile">
    SELECT * FROM enterprise_profile
    WHERE company_name LIKE CONCAT('%', #{keyword}, '%')
    LIMIT 50
</select>
```

**修复方案**:
```xml
<!-- 添加分页参数 -->
<select id="searchByCompanyName" resultType="EnterpriseProfile">
    SELECT * FROM enterprise_profile
    WHERE company_name LIKE CONCAT('%', #{keyword}, '%')
    <if test="offset != null and limit != null">
        LIMIT #{offset}, #{limit}
    </if>
</select>

<!-- 添加 count 查询 -->
<select id="countByCompanyName" resultType="int">
    SELECT COUNT(*) FROM enterprise_profile
    WHERE company_name LIKE CONCAT('%', #{keyword}, '%')
</select>
```

#### Phase 2: Service 层重构（1 人日）

**文件**: `backend/crm/src/main/java/cn/cordys/crm/integration/service/EnterpriseService.java`

**当前问题**:
```java
// 全量加载再分页
public List<Enterprise> searchLocalEnterprise(String keyword, int page, int size) {
    List<Enterprise> all = mapper.searchByKeyword(keyword); // 全量
    return all.subList(page * size, Math.min((page + 1) * size, all.size()));
}
```

**修复方案**:
```java
// SQL 层分页
public PageResult<Enterprise> searchLocalEnterprise(String keyword, int page, int size) {
    int offset = page * size;
    List<Enterprise> results = mapper.searchByKeywordWithPagination(keyword, offset, size);
    int total = mapper.countByKeyword(keyword);
    return new PageResult<>(results, total, page, size);
}
```

#### Phase 3: 测试验证（1 人日）

```bash
# 运行单元测试
mvn test -Dtest=EnterpriseServiceTest

# 运行属性测试
mvn test -Dtest=EnterpriseSearchPaginationPropertyTest

# 性能测试
mvn test -Dtest=EnterpriseSearchPerformanceTest
```

---

## 📋 任务 2: 同步状态自愈（P0 修复）

### 为什么重要？
- ⚠️ 防止数据永久丢失
- ⚠️ 影响用户信任
- ✅ 实现相对简单（2 人日）

### 快速实施步骤

#### Step 1: 添加重置方法（0.5 人日）

**文件**: `mobile/cordyscrm_flutter/lib/services/sync/sync_service.dart`

**添加代码**:
```dart
/// 重置长时间处于 inProgress 状态的队列项
Future<void> _resetStaleInProgressItems() async {
  final staleThreshold = DateTime.now().subtract(Duration(minutes: 5));
  
  final staleItems = await _database.syncQueueDao
      .getStaleInProgressItems(staleThreshold);
  
  if (staleItems.isNotEmpty) {
    _logger.w('Found ${staleItems.length} stale inProgress items, resetting to pending');
    
    for (final item in staleItems) {
      await _database.syncQueueDao.updateStatus(
        item.id,
        SyncStatus.pending,
      );
    }
  }
}
```

#### Step 2: 在初始化时调用（0.5 人日）

```dart
Future<void> initialize() async {
  // 重置 stale 项
  await _resetStaleInProgressItems();
  
  // 继续正常初始化
  _initialized = true;
  _logger.i('SyncService initialized');
}
```

#### Step 3: 添加 DAO 方法（0.5 人日）

**文件**: `mobile/cordyscrm_flutter/lib/data/sources/local/dao/sync_queue_dao.dart`

```dart
@Query('SELECT * FROM sync_queue WHERE status = :status AND updated_at < :threshold')
Future<List<SyncQueueItem>> getStaleInProgressItems(
  SyncStatus status,
  DateTime threshold,
);
```

#### Step 4: 测试验证（0.5 人日）

```bash
# 运行属性测试
cd mobile/cordyscrm_flutter
flutter test test/property_tests/sync_state_recovery_test.dart

# 运行集成测试
flutter test integration_test/sync_service_test.dart
```

---

## 📋 任务 3: 企业去重规范化（P0 修复）

### 快速实施步骤

#### Step 1: 创建规范化工具类（1 人日）

**文件**: `backend/crm/src/main/java/cn/cordys/crm/integration/util/CreditCodeNormalizer.java`

```java
public class CreditCodeNormalizer {
    public static String normalize(String creditCode) {
        if (creditCode == null || creditCode.trim().isEmpty()) {
            return null;
        }
        
        return creditCode.trim()
                         .toUpperCase()
                         .replaceAll("\\s+", "")
                         .replaceAll("[Ａ-Ｚ０-９]", m -> 
                             String.valueOf((char)(m.group().charAt(0) - 0xFEE0)));
    }
}
```

#### Step 2: 集成到服务层（0.5 人日）

**文件**: `backend/crm/src/main/java/cn/cordys/crm/integration/service/EnterpriseService.java`

```java
public EnterpriseImportResponse importEnterprise(EnterpriseImportRequest request) {
    // 规范化信用代码
    request.setCreditCode(CreditCodeNormalizer.normalize(request.getCreditCode()));
    
    // 继续导入逻辑
    // ...
}
```

#### Step 3: 数据清理（1 人日）

**文件**: `backend/crm/src/main/resources/migration/1.6.0/ddl/V1.6.0_3__cleanup_duplicate_credit_codes.sql`

```sql
-- 识别重复记录
WITH duplicates AS (
    SELECT credit_code, MIN(id) as keep_id
    FROM enterprise_profile
    WHERE credit_code IS NOT NULL
    GROUP BY credit_code
    HAVING COUNT(*) > 1
)
-- 删除重复记录（保留 ID 最小的）
DELETE FROM enterprise_profile
WHERE id NOT IN (SELECT keep_id FROM duplicates)
  AND credit_code IN (SELECT credit_code FROM duplicates);

-- 添加唯一索引
ALTER TABLE enterprise_profile
ADD UNIQUE INDEX uk_org_credit_code (org_id, credit_code);
```

#### Step 4: 测试验证（0.5 人日）

```bash
# 运行属性测试
mvn test -Dtest=CreditCodeNormalizationPropertyTest

# 运行迁移测试
mvn test -Dtest=DataMigrationTest
```

---

## 📋 任务 4: AI 成本配置化（P1 优化）

### 快速实施步骤

#### Step 1: 创建数据库表（1 人日）

**文件**: `backend/crm/src/main/resources/migration/1.6.0/ddl/V1.6.0_1__ai_model_pricing.sql`

```sql
CREATE TABLE ai_model_pricing (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    provider VARCHAR(50) NOT NULL COMMENT 'Provider名称',
    model VARCHAR(100) NOT NULL COMMENT '模型名称',
    input_price_per_1k DECIMAL(10, 6) NOT NULL COMMENT '输入token单价',
    output_price_per_1k DECIMAL(10, 6) NOT NULL COMMENT '输出token单价',
    currency VARCHAR(10) DEFAULT 'USD' COMMENT '货币单位',
    effective_date DATETIME NOT NULL COMMENT '生效日期',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_provider_model (provider, model)
) COMMENT 'AI模型定价配置表';
```

#### Step 2: 实现定价服务（2 人日）

**文件**: `backend/crm/src/main/java/cn/cordys/crm/integration/service/AiModelPricingService.java`

```java
@Service
public class AiModelPricingService {
    private final Map<String, AiModelPricing> pricingCache = new ConcurrentHashMap<>();
    
    @PostConstruct
    public void init() {
        refreshCache();
    }
    
    public BigDecimal calculateCost(String provider, String model, 
                                    int inputTokens, int outputTokens) {
        AiModelPricing pricing = getPricing(provider, model);
        
        BigDecimal inputCost = pricing.getInputPricePer1k()
            .multiply(BigDecimal.valueOf(inputTokens))
            .divide(BigDecimal.valueOf(1000), 6, RoundingMode.HALF_UP);
            
        BigDecimal outputCost = pricing.getOutputPricePer1k()
            .multiply(BigDecimal.valueOf(outputTokens))
            .divide(BigDecimal.valueOf(1000), 6, RoundingMode.HALF_UP);
            
        return inputCost.add(outputCost);
    }
}
```

#### Step 3: 集成到 AI 服务（1 人日）

**文件**: `backend/crm/src/main/java/cn/cordys/crm/integration/service/AIService.java`

```java
public LLMResponse generate(String prompt, ProviderType providerType) {
    // ... 调用 LLM
    
    // 使用定价服务计算成本
    BigDecimal cost = pricingService.calculateCost(
        providerType.name(),
        model,
        response.getInputTokens(),
        response.getOutputTokens()
    );
    
    // 记录日志
    logGeneration(prompt, response, cost);
}
```

#### Step 4: 测试验证（1 人日）

```bash
# 运行属性测试
mvn test -Dtest=AiCostCalculationPropertyTest

# 运行集成测试
mvn test -Dtest=AiModelPricingServiceTest
```

---

## 🧪 测试策略

### 单元测试
```bash
# 后端
mvn test

# Flutter
cd mobile/cordyscrm_flutter
flutter test

# Chrome Extension
cd frontend/packages/chrome-extension
pnpm test
```

### 属性测试
```bash
# 后端（jqwik）
mvn test -Dtest=*PropertyTest

# Flutter（fast_check）
flutter test test/property_tests/
```

### 集成测试
```bash
# 启动测试环境
./scripts/start_test_environment.sh

# 运行集成测试
mvn verify -P integration-test
```

---

## 📊 进度跟踪

### 使用 Kiro Tasks

1. 打开对应的 `tasks.md` 文件
2. 点击任务旁边的 "Start task" 按钮
3. 完成后标记为完成

### 手动跟踪

```bash
# 查看当前进度
cat .kiro/specs/*/tasks.md | grep -E "^\- \[x\]" | wc -l

# 查看总任务数
cat .kiro/specs/*/tasks.md | grep -E "^\- \[.\]" | wc -l
```

---

## 🆘 遇到问题？

### 常见问题

**Q: 测试失败怎么办？**
A: 查看 `PROJECT_COMPREHENSIVE_ANALYSIS.md` 中的具体问题分析和修复建议

**Q: 不确定从哪里开始？**
A: 推荐从 "企业搜索分页" 开始，风险最低，见效最快

**Q: 需要更多技术细节？**
A: 查看对应 Spec 的 `design.md` 文件

### 获取帮助

1. 查看完整分析报告: `PROJECT_COMPREHENSIVE_ANALYSIS.md`
2. 查看改进路线图: `PROJECT_IMPROVEMENT_ROADMAP.md`
3. 查看 Spec 文档: `.kiro/specs/*/`

---

## ✅ 完成检查清单

### 任务 1: 企业搜索分页
- [ ] 修改 Mapper XML
- [ ] 更新 Service 层
- [ ] 添加 count 查询
- [ ] 运行单元测试
- [ ] 运行属性测试
- [ ] 性能测试通过

### 任务 2: 同步状态自愈
- [ ] 添加重置方法
- [ ] 更新初始化逻辑
- [ ] 添加 DAO 方法
- [ ] 运行属性测试
- [ ] 集成测试通过

### 任务 3: 企业去重规范化
- [ ] 创建规范化工具类
- [ ] 集成到服务层
- [ ] 编写数据清理 SQL
- [ ] 执行迁移
- [ ] 验证数据完整性

### 任务 4: AI 成本配置化
- [ ] 创建数据库表
- [ ] 实现定价服务
- [ ] 集成到 AI 服务
- [ ] 添加 REST API
- [ ] 运行属性测试

---

**祝你修复顺利！** 🚀

如有问题，请参考完整文档或联系团队。

