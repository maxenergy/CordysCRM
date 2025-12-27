# Implementation Plan: AI Cost Configuration & Pricing Strategy

## Overview

This implementation plan addresses the P1 issue where AI cost calculation uses a hardcoded price (`$0.01/1000 tokens`) for all models. The fix involves creating a database-backed pricing configuration system with caching, supporting multiple providers and separate input/output token pricing.

## Tasks

- [ ] 1. Phase 1: Database Schema - Create Pricing Table
  - Create ai_model_pricing table with proper indexes
  - Insert default pricing for existing models
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [ ] 1.1 Create database migration script
  - Create SQL migration file `V1.6.0_1__ai_model_pricing.sql`
  - Define table schema with all required fields
  - Add unique constraint on (provider_code, model_code)
  - Add indexes for performance
  - _Requirements: 1.1_

- [ ] 1.2 Insert default pricing data
  - Add pricing for OpenAI models (gpt-4, gpt-3.5-turbo)
  - Add pricing for Aliyun models (qwen-max, qwen-plus)
  - Add pricing for any other configured providers
  - _Requirements: 1.2, 3.1_

- [ ]* 1.3 Write unit tests for database schema
  - Test table creation succeeds
  - Test unique constraint on provider/model
  - Test indexes exist
  - Test default data insertion
  - _Requirements: 1.1_

- [ ] 2. Phase 2: Domain and Mapper Layer
  - Create domain entity and mapper for pricing configuration
  - _Requirements: 1.1, 2.1, 2.4, 8.1, 8.2, 8.3, 8.4_

- [ ] 2.1 Create AiModelPricing domain entity
  - Define all fields (id, provider_code, model_code, prices, etc.)
  - Implement `getCacheKey()` method
  - Implement `calculateCost(inputTokens, outputTokens)` method using BigDecimal
  - _Requirements: 1.4, 2.2, 2.4_

- [ ] 2.2 Create AiModelPricingMapper interface
  - Define `selectAllActive()` method
  - Define `selectByProviderAndModel(provider, model)` method
  - Define `insert(pricing)` method
  - Define `update(pricing)` method
  - Define `deleteById(id)` method
  - _Requirements: 8.1, 8.2, 8.3, 8.4_

- [ ] 2.3 Create AiModelPricingMapper.xml
  - Implement SQL for selectAllActive
  - Implement SQL for selectByProviderAndModel
  - Implement SQL for insert
  - Implement SQL for update
  - Implement SQL for deleteById
  - _Requirements: 8.1, 8.2, 8.3, 8.4_

- [ ]* 2.4 Write unit tests for Mapper layer
  - Test selectAllActive returns all active records
  - Test selectByProviderAndModel returns correct record
  - Test insert creates new record
  - Test update modifies existing record
  - Test deleteById removes record
  - _Requirements: 8.1, 8.2, 8.3, 8.4_

- [ ] 3. Phase 3: Pricing Service with Caching
  - Implement service layer with in-memory caching
  - _Requirements: 2.1, 2.3, 4.1, 4.2, 4.3, 4.4, 6.1, 6.2, 6.3_

- [ ] 3.1 Create AiModelPricingService class
  - Implement `@PostConstruct initialize()` method to load cache
  - Implement `@Scheduled refreshCache()` method (every 1 hour)
  - Implement `getPricing(provider, model)` method with fallback
  - Implement `createPricing(pricing)` method
  - Implement `updatePricing(pricing)` method
  - Implement `getAllPricing()` method
  - Use ConcurrentHashMap for thread-safe cache
  - _Requirements: 4.1, 4.2, 4.3, 6.1, 6.2, 6.3_

- [ ] 3.2 Add fallback pricing configuration
  - Add `ai.pricing.fallback.input` property to application.yml
  - Add `ai.pricing.fallback.output` property to application.yml
  - Implement `createFallbackPricing()` method
  - Log warning when fallback is used
  - _Requirements: 6.1, 6.2, 6.3_

- [ ]* 3.3 Write unit tests for Pricing Service
  - Test initialize() loads all pricing into cache
  - Test refreshCache() updates cache
  - Test getPricing() returns correct pricing from cache
  - Test getPricing() returns fallback when not configured
  - Test createPricing() persists and refreshes cache
  - Test updatePricing() persists and refreshes cache
  - _Requirements: 4.1, 4.2, 4.3, 6.1_

- [ ] 4. Checkpoint - Verify Pricing Service
  - Ensure all tests pass
  - Manually test cache initialization
  - Manually test fallback pricing
  - Ask the user if questions arise

- [ ] 5. Phase 4: Update AIService
  - Integrate pricing service into AI generation flow
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 3.2, 3.3, 5.1, 5.2, 5.3_

- [ ] 5.1 Inject AiModelPricingService into AIService
  - Add `@Resource private AiModelPricingService pricingService;`
  - _Requirements: 2.1_

- [ ] 5.2 Implement calculateCost() method
  - Replace hardcoded calculation with pricing lookup
  - Call `pricingService.getPricing(provider, model)`
  - Call `pricing.calculateCost(inputTokens, outputTokens)`
  - Use BigDecimal for all calculations
  - _Requirements: 2.1, 2.2, 2.4_

- [ ] 5.3 Update generate() method
  - Extract provider code and model code from response
  - Call new `calculateCost()` method
  - Pass accurate cost to `logGeneration()`
  - _Requirements: 2.1, 2.2, 5.1_

- [ ] 5.4 Update AIGenerationLog entity
  - Add `providerCode` field
  - Add `modelCode` field
  - Add `inputTokens` field
  - Add `outputTokens` field
  - Add `inputPricePer1k` field
  - Add `outputPricePer1k` field
  - Add `currency` field
  - _Requirements: 5.1, 5.2, 5.3_

- [ ] 5.5 Update logGeneration() method
  - Store provider code and model code
  - Store input and output token counts
  - Store pricing used for calculation
  - Store currency
  - _Requirements: 5.1, 5.2, 5.3_

- [ ]* 5.6 Write unit tests for updated AIService
  - Test calculateCost() uses correct pricing
  - Test generate() logs accurate cost
  - Test fallback pricing is used when model not configured
  - Mock AiModelPricingService for isolation
  - _Requirements: 2.1, 2.2, 2.3, 5.1_

- [ ] 6. Checkpoint - Verify AI Cost Calculation
  - Ensure all tests pass
  - Manually test AI generation with different models
  - Verify cost logs contain accurate pricing details
  - Ask the user if questions arise

- [ ] 7. Phase 5: Property-Based Testing
  - Implement property tests to verify universal correctness
  - Run tests with minimum 100 iterations each
  - _Requirements: 1.2, 1.4, 2.1, 2.2, 2.4, 3.1, 4.1, 6.1_

- [ ]* 7.1 Write property test for Pricing Lookup Accuracy
  - **Property 1: Pricing Lookup Accuracy**
  - **Validates: Requirements 2.1, 4.3**
  - Generate random provider, model, input price, output price
  - Insert pricing into database
  - Call getPricing(provider, model)
  - Verify returned pricing matches inserted values
  - _Requirements: 2.1, 4.3_

- [ ]* 7.2 Write property test for Cost Calculation Accuracy
  - **Property 2: Cost Calculation Accuracy**
  - **Validates: Requirements 2.2, 2.4**
  - Generate random input tokens, output tokens, input price, output price
  - Create pricing with given prices
  - Calculate cost
  - Verify cost = (inputTokens * inputPrice / 1000) + (outputTokens * outputPrice / 1000)
  - Verify BigDecimal precision to 6 decimal places
  - _Requirements: 2.2, 2.4_

- [ ]* 7.3 Write property test for Multi-Provider Independence
  - **Property 3: Multi-Provider Support**
  - **Validates: Requirements 3.1, 1.2, 1.4**
  - Generate random list of pricing configurations
  - Insert all configurations
  - Update one pricing
  - Verify other pricings remain unchanged
  - _Requirements: 3.1, 1.2, 1.4_

- [ ]* 7.4 Write property test for Cache Initialization
  - **Property 4: Cache Initialization**
  - **Validates: Requirements 4.1**
  - Generate random number of pricing configs (1-50)
  - Insert configs into database
  - Call initialize()
  - Verify cache size equals number of configs
  - Verify all records are in cache
  - _Requirements: 4.1_

- [ ]* 7.5 Write property test for Fallback Pricing
  - **Property 6: Fallback Pricing**
  - **Validates: Requirements 2.3, 6.1, 6.2, 6.3**
  - Generate random provider and model NOT in database
  - Call getPricing(provider, model)
  - Verify returns fallback pricing
  - Verify warning logged with provider and model
  - _Requirements: 2.3, 6.1, 6.2, 6.3_

- [ ] 8. Checkpoint - Verify Property Tests
  - Ensure all property tests pass with 100+ iterations
  - Review any failing test cases
  - Ask the user if questions arise

- [ ] 9. Phase 6: REST API for Pricing Management
  - Create REST endpoints for pricing CRUD operations
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [ ] 9.1 Create AiModelPricingController
  - Implement GET /api/ai/pricing - list all pricing
  - Implement GET /api/ai/pricing/{provider}/{model} - get specific pricing
  - Implement POST /api/ai/pricing - create new pricing
  - Implement PUT /api/ai/pricing/{id} - update pricing
  - Implement DELETE /api/ai/pricing/{id} - delete pricing
  - Implement POST /api/ai/pricing/refresh - manual cache refresh
  - Add @PreAuthorize("hasRole('ADMIN')") to all endpoints
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [ ] 9.2 Create DTO classes
  - Create AiModelPricingRequest DTO
  - Create AiModelPricingResponse DTO
  - Add validation annotations (@NotNull, @Positive, etc.)
  - _Requirements: 8.1, 8.2, 8.3_

- [ ]* 9.3 Write integration tests for REST API
  - Test GET /api/ai/pricing returns all pricing
  - Test POST /api/ai/pricing creates new pricing
  - Test PUT /api/ai/pricing/{id} updates pricing
  - Test DELETE /api/ai/pricing/{id} deletes pricing
  - Test POST /api/ai/pricing/refresh refreshes cache
  - Test endpoints require admin authentication
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

- [ ] 10. Final Checkpoint - Production Readiness
  - All tests pass (unit, property, integration)
  - Code review completed
  - API documentation updated
  - Database migration tested
  - Fallback pricing configured
  - Ask the user if ready for deployment

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties
- Unit tests validate specific examples and edge cases
- Integration tests validate end-to-end functionality

## Implementation Order

1. **Phase 1** (Database): Foundation for pricing storage
2. **Phase 2** (Mapper): Data access layer
3. **Phase 3** (Service): Business logic with caching
4. **Checkpoint**: Verify pricing service works
5. **Phase 4** (AIService): Integrate with AI generation
6. **Checkpoint**: Verify cost calculation works
7. **Phase 5** (Property Tests): Verify universal properties
8. **Checkpoint**: Verify properties hold
9. **Phase 6** (REST API): Management interface
10. **Final Checkpoint**: Production readiness

## Rollback Strategy

If issues are discovered during implementation:
1. Phase 1-3 changes are safe (new tables and services don't affect existing code)
2. Phase 4 changes can be reverted by restoring old AIService.calculateCost()
3. Phase 6 API can be disabled by removing controller
4. Monitor AI generation logs for cost accuracy after deployment

## Migration Notes

### Database Migration
- Run migration script during deployment
- Verify default pricing data is inserted
- Backup existing ai_generation_log table before schema changes

### Configuration
- Add fallback pricing to application.yml:
  ```yaml
  ai:
    pricing:
      fallback:
        input: 0.01
        output: 0.01
  ```

### Monitoring
- Monitor pricing cache refresh logs
- Monitor fallback pricing usage (indicates missing config)
- Monitor cost calculation accuracy in ai_generation_log
