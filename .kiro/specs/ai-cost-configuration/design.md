# Design Document: AI Cost Configuration & Pricing Strategy

## Overview

This design replaces the hardcoded AI cost calculation (`$0.01/1000 tokens`) with a flexible, database-backed pricing configuration system. The solution supports multiple providers, separate input/output token pricing, and runtime price updates without redeployment.

### Current Implementation

```java
// AIService.java - Hardcoded pricing
BigDecimal cost = BigDecimal.valueOf(totalTokens * 0.00001); // $0.01/1000 tokens
```

**Problems**:
- Same price for all models (GPT-4 and GPT-3.5 have very different costs)
- No distinction between input and output tokens
- Cannot update prices without redeployment
- Inaccurate billing and cost tracking

### Proposed Implementation

```java
// AIService.java - Database-backed pricing
AiModelPricing pricing = pricingCache.get(provider, model);
BigDecimal cost = (inputTokens * pricing.getInputPrice() / 1000) 
                + (outputTokens * pricing.getOutputPrice() / 1000);
```

**Benefits**:
- Accurate pricing per provider and model
- Separate input/output token pricing
- Runtime price updates via database
- Proper cost tracking and auditing

## Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    AIController                              │
│  - generatePortrait(customerId)                             │
│  - generateCallScript(templateId, params)                   │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                      AIService                               │
│  - generate(prompt, providerType)                           │
│  - calculateCost(provider, model, inputTokens, outputTokens)│
│  - pricingCache: Map<String, AiModelPricing>               │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                AiModelPricingService                         │
│  - loadAllPricing()                                          │
│  - getPricing(provider, model)                              │
│  - updatePricing(pricing)                                   │
│  - refreshCache()                                           │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              AiModelPricingMapper                            │
│  - selectAll()                                               │
│  - selectByProviderAndModel(provider, model)                │
│  - insert(pricing)                                          │
│  - update(pricing)                                          │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                    MySQL Database                            │
│  Table: ai_model_pricing                                     │
│  - id, provider_code, model_code                            │
│  - input_price_per_1k, output_price_per_1k                  │
│  - currency, create_time, update_time                       │
└─────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. Database Schema

**Table: ai_model_pricing**

```sql
CREATE TABLE ai_model_pricing (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    provider_code VARCHAR(50) NOT NULL COMMENT 'Provider identifier (openai, aliyun, claude)',
    model_code VARCHAR(100) NOT NULL COMMENT 'Model identifier (gpt-4, gpt-3.5-turbo, qwen-max)',
    input_price_per_1k DECIMAL(10, 6) NOT NULL COMMENT 'Cost per 1000 input tokens',
    output_price_per_1k DECIMAL(10, 6) NOT NULL COMMENT 'Cost per 1000 output tokens',
    currency VARCHAR(10) NOT NULL DEFAULT 'USD' COMMENT 'Currency code (USD, CNY)',
    is_active TINYINT(1) NOT NULL DEFAULT 1 COMMENT 'Whether this pricing is active',
    create_time BIGINT NOT NULL,
    update_time BIGINT NOT NULL,
    create_user VARCHAR(50),
    update_user VARCHAR(50),
    UNIQUE KEY uk_provider_model (provider_code, model_code),
    INDEX idx_provider (provider_code),
    INDEX idx_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI model pricing configuration';

-- Insert default pricing
INSERT INTO ai_model_pricing (provider_code, model_code, input_price_per_1k, output_price_per_1k, currency, create_time, update_time) VALUES
('openai', 'gpt-4', 0.03, 0.06, 'USD', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('openai', 'gpt-3.5-turbo', 0.001, 0.002, 'USD', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('aliyun', 'qwen-max', 0.02, 0.02, 'CNY', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000),
('aliyun', 'qwen-plus', 0.004, 0.004, 'CNY', UNIX_TIMESTAMP() * 1000, UNIX_TIMESTAMP() * 1000);
```

### 2. Domain Entity

**File**: `backend/crm/src/main/java/cn/cordys/crm/integration/domain/AiModelPricing.java`

```java
package cn.cordys.crm.integration.domain;

import lombok.Data;
import java.math.BigDecimal;

/**
 * AI Model Pricing Configuration
 * 
 * Requirements: 1.1, 1.2, 1.3, 1.4, 2.1, 2.2, 2.4, 3.1, 3.2, 3.4
 */
@Data
public class AiModelPricing {
    private Long id;
    private String providerCode;
    private String modelCode;
    private BigDecimal inputPricePer1k;
    private BigDecimal outputPricePer1k;
    private String currency;
    private Boolean isActive;
    private Long createTime;
    private Long updateTime;
    private String createUser;
    private String updateUser;
    
    /**
     * Get cache key for this pricing configuration
     */
    public String getCacheKey() {
        return providerCode + ":" + modelCode;
    }
    
    /**
     * Calculate cost for given token counts
     * 
     * Property 2: Cost Calculation Accuracy
     * 
     * @param inputTokens Number of input tokens
     * @param outputTokens Number of output tokens
     * @return Total cost in the configured currency
     */
    public BigDecimal calculateCost(int inputTokens, int outputTokens) {
        BigDecimal inputCost = inputPricePer1k
            .multiply(BigDecimal.valueOf(inputTokens))
            .divide(BigDecimal.valueOf(1000), 6, BigDecimal.ROUND_HALF_UP);
            
        BigDecimal outputCost = outputPricePer1k
            .multiply(BigDecimal.valueOf(outputTokens))
            .divide(BigDecimal.valueOf(1000), 6, BigDecimal.ROUND_HALF_UP);
            
        return inputCost.add(outputCost);
    }
}
```

### 3. Mapper Interface

**File**: `backend/crm/src/main/java/cn/cordys/crm/integration/mapper/AiModelPricingMapper.java`

```java
package cn.cordys.crm.integration.mapper;

import cn.cordys.crm.integration.domain.AiModelPricing;
import org.apache.ibatis.annotations.Param;
import java.util.List;

/**
 * AI Model Pricing Mapper
 * 
 * Requirements: 1.1, 4.1, 8.1, 8.2, 8.3, 8.4
 */
public interface AiModelPricingMapper {
    
    /**
     * Select all active pricing configurations
     */
    List<AiModelPricing> selectAllActive();
    
    /**
     * Select pricing by provider and model
     */
    AiModelPricing selectByProviderAndModel(
        @Param("providerCode") String providerCode,
        @Param("modelCode") String modelCode
    );
    
    /**
     * Insert new pricing configuration
     */
    int insert(AiModelPricing pricing);
    
    /**
     * Update existing pricing configuration
     */
    int update(AiModelPricing pricing);
    
    /**
     * Delete pricing configuration
     */
    int deleteById(@Param("id") Long id);
}
```

### 4. Pricing Service

**File**: `backend/crm/src/main/java/cn/cordys/crm/integration/service/AiModelPricingService.java`

```java
package cn.cordys.crm.integration.service;

import cn.cordys.crm.integration.domain.AiModelPricing;
import cn.cordys.crm.integration.mapper.AiModelPricingMapper;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.Resource;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * AI Model Pricing Service
 * 
 * Manages pricing configuration with in-memory caching
 * 
 * Requirements: 1.1, 1.2, 1.3, 2.1, 2.3, 4.1, 4.2, 4.3, 6.1, 6.2, 6.3
 */
@Slf4j
@Service
public class AiModelPricingService {
    
    @Resource
    private AiModelPricingMapper pricingMapper;
    
    @Value("${ai.pricing.fallback.input:0.01}")
    private BigDecimal fallbackInputPrice;
    
    @Value("${ai.pricing.fallback.output:0.01}")
    private BigDecimal fallbackOutputPrice;
    
    // Cache: "provider:model" -> AiModelPricing
    private final Map<String, AiModelPricing> pricingCache = new ConcurrentHashMap<>();
    
    /**
     * Initialize cache on startup
     * 
     * Property 4: Cache Initialization
     */
    @PostConstruct
    public void initialize() {
        refreshCache();
        log.info("AI pricing cache initialized with {} configurations", pricingCache.size());
    }
    
    /**
     * Refresh cache every hour
     * 
     * Property 5: Cache Refresh
     */
    @Scheduled(fixedRate = 3600000) // 1 hour
    public void refreshCache() {
        try {
            List<AiModelPricing> allPricing = pricingMapper.selectAllActive();
            
            // Clear and rebuild cache
            pricingCache.clear();
            for (AiModelPricing pricing : allPricing) {
                pricingCache.put(pricing.getCacheKey(), pricing);
            }
            
            log.info("AI pricing cache refreshed: {} configurations loaded", allPricing.size());
        } catch (Exception e) {
            log.error("Failed to refresh pricing cache", e);
        }
    }
    
    /**
     * Get pricing for a specific provider and model
     * 
     * Property 1: Pricing Lookup Accuracy
     * Property 6: Fallback Pricing
     * 
     * @param providerCode Provider identifier
     * @param modelCode Model identifier
     * @return Pricing configuration (never null, uses fallback if not found)
     */
    public AiModelPricing getPricing(String providerCode, String modelCode) {
        String cacheKey = providerCode + ":" + modelCode;
        AiModelPricing pricing = pricingCache.get(cacheKey);
        
        if (pricing == null) {
            log.warn("No pricing configured for {}:{}, using fallback", providerCode, modelCode);
            pricing = createFallbackPricing(providerCode, modelCode);
        }
        
        return pricing;
    }
    
    /**
     * Create fallback pricing when configuration is missing
     */
    private AiModelPricing createFallbackPricing(String providerCode, String modelCode) {
        AiModelPricing fallback = new AiModelPricing();
        fallback.setProviderCode(providerCode);
        fallback.setModelCode(modelCode);
        fallback.setInputPricePer1k(fallbackInputPrice);
        fallback.setOutputPricePer1k(fallbackOutputPrice);
        fallback.setCurrency("USD");
        return fallback;
    }
    
    /**
     * Create new pricing configuration
     */
    public void createPricing(AiModelPricing pricing) {
        pricing.setCreateTime(System.currentTimeMillis());
        pricing.setUpdateTime(System.currentTimeMillis());
        pricingMapper.insert(pricing);
        refreshCache();
    }
    
    /**
     * Update existing pricing configuration
     */
    public void updatePricing(AiModelPricing pricing) {
        pricing.setUpdateTime(System.currentTimeMillis());
        pricingMapper.update(pricing);
        refreshCache();
    }
    
    /**
     * Get all pricing configurations
     */
    public List<AiModelPricing> getAllPricing() {
        return pricingMapper.selectAllActive();
    }
}
```

### 5. Updated AIService

**File**: `backend/crm/src/main/java/cn/cordys/crm/integration/service/AIService.java`

**Changes**:

```java
@Resource
private AiModelPricingService pricingService;

/**
 * Calculate cost using configured pricing
 * 
 * Property 2: Cost Calculation Accuracy
 * Property 3: Multi-Provider Support
 * 
 * @param providerCode Provider identifier
 * @param modelCode Model identifier
 * @param inputTokens Number of input tokens
 * @param outputTokens Number of output tokens
 * @return Total cost
 */
private BigDecimal calculateCost(String providerCode, String modelCode, 
                                 int inputTokens, int outputTokens) {
    AiModelPricing pricing = pricingService.getPricing(providerCode, modelCode);
    return pricing.calculateCost(inputTokens, outputTokens);
}

/**
 * Generate AI content with accurate cost tracking
 */
public LLMResponse generate(String prompt, ProviderType providerType) {
    LLMProvider provider = providers.get(providerType);
    if (provider == null) {
        throw new IllegalArgumentException("Unknown provider: " + providerType);
    }
    
    // Generate content
    LLMResponse response = provider.generate(prompt);
    
    // Calculate cost using configured pricing
    BigDecimal cost = calculateCost(
        providerType.getCode(),
        response.getModel(),
        response.getInputTokens(),
        response.getOutputTokens()
    );
    
    // Log generation with accurate cost
    logGeneration(prompt, response, cost);
    
    return response;
}
```

## Data Models

### Updated AIGenerationLog

Add fields to track pricing details:

```java
private String providerCode;
private String modelCode;
private Integer inputTokens;
private Integer outputTokens;
private BigDecimal inputPricePer1k;
private BigDecimal outputPricePer1k;
private String currency;
```

## Correctness Properties

### Acceptance Criteria Testing Prework

**1.1 THE System SHALL store AI model pricing in a database table**
- Thoughts: This is an implementation requirement. We can verify the table exists and has correct schema.
- Testable: yes - example

**1.2 WHEN a new AI model is added, THE System SHALL allow administrators to configure its pricing**
- Thoughts: This is testing the create operation. For any valid pricing configuration, insert should succeed.
- Testable: yes - property

**1.4 THE System SHALL support different pricing for input tokens and output tokens**
- Thoughts: This is testing that input and output prices can be different. For any two different prices, they should be stored and retrieved correctly.
- Testable: yes - property

**2.1 WHEN calculating cost, THE System SHALL use the configured price for the specific provider and model**
- Thoughts: This is testing lookup accuracy. For any provider/model combination, the correct pricing should be used.
- Testable: yes - property

**2.2 WHEN a model has separate input and output prices, THE System SHALL calculate cost correctly**
- Thoughts: This is testing the cost formula. For any input/output token counts and prices, the calculation should match the formula.
- Testable: yes - property

**2.3 WHEN pricing is not configured, THE System SHALL use a safe default and log a warning**
- Thoughts: This is testing fallback behavior. For any unconfigured model, fallback pricing should be used.
- Testable: yes - property

**2.4 THE System SHALL use BigDecimal for all cost calculations**
- Thoughts: This is an implementation requirement. We can verify BigDecimal is used in the code.
- Testable: yes - example

**3.1 THE System SHALL support pricing for multiple providers**
- Thoughts: This is testing multi-provider support. For any set of providers, each should have independent pricing.
- Testable: yes - property

**4.1 WHEN the service starts, THE System SHALL load all pricing into memory**
- Thoughts: This is testing cache initialization. After startup, cache should contain all active pricing.
- Testable: yes - property

**4.2 WHEN pricing is updated, THE System SHALL refresh the cache within 1 hour**
- Thoughts: This is testing cache refresh. After update, cache should reflect new pricing within TTL.
- Testable: yes - example

**4.3 WHEN calculating cost, THE System SHALL use cached pricing**
- Thoughts: This is testing cache usage. Cost calculation should not query database.
- Testable: yes - property

**6.1 WHEN pricing is not configured, THE System SHALL use default fallback**
- Thoughts: This is testing fallback behavior. Same as 2.3.
- Testable: yes - property

### Property Reflection

After reviewing the prework:

- Properties 2.1, 4.3 both test pricing lookup → Combine into Property 1
- Properties 2.2, 2.4 both test cost calculation → Combine into Property 2
- Properties 3.1, 1.2, 1.4 all test multi-provider/model support → Combine into Property 3
- Property 4.1 tests cache initialization → Keep as Property 4
- Property 4.2 tests cache refresh → Keep as Property 5
- Properties 2.3, 6.1 both test fallback → Combine into Property 6

### Correctness Properties

A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.

**Property 1: Pricing Lookup Accuracy**

*For any* configured provider and model combination, calling `getPricing(provider, model)` SHALL return the exact pricing configuration stored in the database, with input price, output price, and currency matching the database values.

**Validates: Requirements 2.1, 4.3**

**Property 2: Cost Calculation Accuracy**

*For any* input token count I, output token count O, input price P_in, and output price P_out, the calculated cost SHALL equal `(I * P_in / 1000) + (O * P_out / 1000)` with precision to 6 decimal places using BigDecimal arithmetic.

**Validates: Requirements 2.2, 2.4**

**Property 3: Multi-Provider Support**

*For any* set of providers and models, each provider/model combination SHALL have independent pricing configuration, and updating one SHALL NOT affect others.

**Validates: Requirements 3.1, 1.2, 1.4**

**Property 4: Cache Initialization**

*For any* service startup, after the `@PostConstruct` method completes, the pricing cache SHALL contain all active pricing configurations from the database, with cache size equal to the count of active records.

**Validates: Requirements 4.1**

**Property 5: Cache Refresh**

*For any* pricing update in the database, calling `refreshCache()` SHALL update the in-memory cache to reflect the new pricing within 100ms, and subsequent `getPricing()` calls SHALL return the updated pricing.

**Validates: Requirements 4.2**

**Property 6: Fallback Pricing**

*For any* unconfigured provider/model combination, calling `getPricing(provider, model)` SHALL return a fallback pricing configuration with the default input and output prices, and SHALL log a warning message containing the provider and model codes.

**Validates: Requirements 2.3, 6.1, 6.2, 6.3**

**Property 7: Pricing Persistence**

*For any* valid pricing configuration, calling `createPricing()` SHALL persist the configuration to the database, and subsequent `getPricing()` calls SHALL return the persisted configuration.

**Validates: Requirements 1.1, 1.2**

**Property 8: Cost Audit Trail**

*For any* AI generation request, the system SHALL log the cost calculation with provider, model, input tokens, output tokens, input price, output price, and total cost, and the log SHALL be retrievable from the database.

**Validates: Requirements 5.1, 5.2, 5.3**

## Error Handling

### Invalid Pricing Configuration
- Negative prices → Reject with validation error
- Null provider/model → Reject with validation error
- Duplicate provider/model → Reject with unique constraint error

### Database Errors
- Connection failure during cache refresh → Log error, keep existing cache
- Insert/update failure → Return error to caller
- Query timeout → Retry once, then fail

### Missing Pricing
- Unconfigured model → Use fallback pricing and log warning
- Fallback pricing not configured → Use hardcoded safe default ($0.01/1k)

## Testing Strategy

### Dual Testing Approach

- **Unit tests**: Verify specific examples, edge cases, and error conditions
- **Property tests**: Verify universal properties across all inputs
- Both are complementary and necessary for comprehensive coverage

### Unit Testing

1. **Database Schema**: Verify table structure and indexes
2. **CRUD Operations**: Test create, read, update, delete
3. **Cache Initialization**: Verify cache loads on startup
4. **Fallback Pricing**: Verify fallback when pricing missing
5. **Cost Calculation**: Test specific examples (GPT-4, GPT-3.5)

### Property-Based Testing

**Configuration**: Each property test MUST run minimum 100 iterations.

**Test 1: Pricing Lookup Accuracy**
```java
@Property(tries = 100)
void pricingLookupAccuracy(@ForAll String provider, @ForAll String model,
                           @ForAll @BigRange(min = "0.001", max = "1.0") BigDecimal inputPrice,
                           @ForAll @BigRange(min = "0.001", max = "1.0") BigDecimal outputPrice) {
    // Setup: Insert pricing into database
    // Execute: Call getPricing(provider, model)
    // Verify: Returned pricing matches inserted values
}
```
**Feature: ai-cost-configuration, Property 1: Pricing Lookup Accuracy**

**Test 2: Cost Calculation Accuracy**
```java
@Property(tries = 100)
void costCalculationAccuracy(@ForAll @IntRange(min = 1, max = 10000) int inputTokens,
                             @ForAll @IntRange(min = 1, max = 10000) int outputTokens,
                             @ForAll @BigRange(min = "0.001", max = "1.0") BigDecimal inputPrice,
                             @ForAll @BigRange(min = "0.001", max = "1.0") BigDecimal outputPrice) {
    // Setup: Create pricing with given prices
    // Execute: Calculate cost
    // Verify: Cost = (inputTokens * inputPrice / 1000) + (outputTokens * outputPrice / 1000)
}
```
**Feature: ai-cost-configuration, Property 2: Cost Calculation Accuracy**

**Test 3: Multi-Provider Independence**
```java
@Property(tries = 100)
void multiProviderIndependence(@ForAll List<AiModelPricing> pricingConfigs) {
    // Setup: Insert multiple pricing configurations
    // Execute: Update one pricing
    // Verify: Other pricings remain unchanged
}
```
**Feature: ai-cost-configuration, Property 3: Multi-Provider Support**

**Test 4: Cache Initialization**
```java
@Property(tries = 100)
void cacheInitialization(@ForAll @IntRange(min = 1, max = 50) int numConfigs) {
    // Setup: Insert numConfigs pricing records
    // Execute: Call initialize()
    // Verify: Cache size equals numConfigs
    // Verify: All records are in cache
}
```
**Feature: ai-cost-configuration, Property 4: Cache Initialization**

**Test 5: Fallback Pricing**
```java
@Property(tries = 100)
void fallbackPricing(@ForAll String provider, @ForAll String model) {
    // Setup: Ensure provider/model NOT in database
    // Execute: Call getPricing(provider, model)
    // Verify: Returns fallback pricing
    // Verify: Warning logged
}
```
**Feature: ai-cost-configuration, Property 6: Fallback Pricing**

## Performance Considerations

### Cache Performance
- Cache lookup: O(1) using ConcurrentHashMap
- Cache refresh: O(N) where N is number of pricing configs
- Expected N < 100, so refresh < 10ms

### Database Indexes
```sql
CREATE UNIQUE INDEX uk_provider_model ON ai_model_pricing(provider_code, model_code);
CREATE INDEX idx_provider ON ai_model_pricing(provider_code);
CREATE INDEX idx_active ON ai_model_pricing(is_active);
```

### Concurrency
- Use ConcurrentHashMap for thread-safe cache access
- Use @Scheduled for automatic cache refresh
- No locks needed for read operations

## Migration Strategy

### Phase 1: Database Schema
1. Create `ai_model_pricing` table
2. Insert default pricing for existing models
3. Verify schema with unit tests

### Phase 2: Service Layer
1. Implement `AiModelPricingService`
2. Update `AIService` to use new pricing
3. Keep old hardcoded calculation as fallback

### Phase 3: API Layer
1. Add REST endpoints for pricing management
2. Add admin UI for pricing configuration
3. Document API

### Phase 4: Migration
1. Verify all AI generations use new pricing
2. Remove old hardcoded calculation
3. Monitor cost logs for accuracy

## Rollback Plan

If issues are discovered:
1. Revert `AIService` to use hardcoded pricing
2. Keep `ai_model_pricing` table (no harm)
3. Fix issues and redeploy

## Monitoring

Add logging for:
- Pricing cache refresh (success/failure)
- Fallback pricing usage (indicates missing config)
- Cost calculation (for audit trail)
- Pricing updates (for change tracking)
