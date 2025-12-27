# Design Document: Enterprise Search SQL Pagination Fix

## Overview

This design addresses the critical data accessibility bug in enterprise search by replacing in-memory pagination with SQL-level pagination. The current implementation has a hardcoded `LIMIT 50` in the SQL query, preventing users from accessing records beyond the first 50 results.

### Current Architecture

```
SQL Query (LIMIT 50) → Service (List.subList) → Controller → Client
```

**Problem**: Users can never access records 51+, even though they exist in the database.

### Proposed Architecture

```
SQL Query (LIMIT offset, size) → Service (Direct Return) → Controller → Client
```

**Solution**: Database handles pagination, ensuring all records are accessible.

## Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      EnterpriseController                    │
│  - searchLocalEnterprise(keyword, page, size)               │
│  - searchEnterprise(keyword, page, size)                    │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                     EnterpriseService                        │
│  - searchLocalEnterprise(keyword, page, size, orgId)        │
│  - searchEnterprise(keyword, page, size, orgId)             │
│  - Calculates offset = (page - 1) * size                    │
│  - Merges local + remote for hybrid search                  │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              ExtEnterpriseProfileMapper                      │
│  - searchByCompanyName(name, orgId, offset, limit)          │
│  - countByCompanyName(name, orgId)                          │
└─────────────────────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                    MySQL Database                            │
│  SELECT ... FROM enterprise_profile                          │
│  WHERE company_name LIKE ... AND organization_id = ...       │
│  ORDER BY create_time DESC                                   │
│  LIMIT #{offset}, #{limit}                                   │
└─────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. ExtEnterpriseProfileMapper (Mapper Layer)

**File**: `backend/crm/src/main/java/cn/cordys/crm/integration/mapper/ExtEnterpriseProfileMapper.java`

**Changes**:

```java
public interface ExtEnterpriseProfileMapper {
    // Existing methods...
    
    /**
     * Search enterprises by company name with pagination
     * @param companyName Search keyword
     * @param orgId Organization ID
     * @param offset Starting position (0-based)
     * @param limit Number of records to return
     * @return List of matching enterprise profiles
     */
    List<EnterpriseProfile> searchByCompanyName(
        @Param("companyName") String companyName,
        @Param("orgId") String orgId,
        @Param("offset") int offset,
        @Param("limit") int limit
    );
    
    /**
     * Count enterprises matching the search criteria
     * @param companyName Search keyword
     * @param orgId Organization ID
     * @return Total count of matching records
     */
    int countByCompanyName(
        @Param("companyName") String companyName,
        @Param("orgId") String orgId
    );
}
```

**XML Changes** (`ExtEnterpriseProfileMapper.xml`):

```xml
<select id="searchByCompanyName" resultType="cn.cordys.crm.integration.domain.EnterpriseProfile">
    SELECT id, customer_id, iqicha_id, credit_code, company_name, legal_person,
           reg_capital, reg_date, staff_size, industry_code, industry_name,
           province, city, address, status, phone, email, website,
           shareholders, executives, risks, source, last_sync_at,
           organization_id, create_time, update_time, create_user, update_user
    FROM enterprise_profile
    WHERE company_name LIKE CONCAT('%', #{companyName}, '%')
      AND organization_id = #{orgId}
    ORDER BY create_time DESC
    LIMIT #{offset}, #{limit}
</select>

<select id="countByCompanyName" resultType="int">
    SELECT COUNT(*)
    FROM enterprise_profile
    WHERE company_name LIKE CONCAT('%', #{companyName}, '%')
      AND organization_id = #{orgId}
</select>
```

### 2. EnterpriseService (Service Layer)

**File**: `backend/crm/src/main/java/cn/cordys/crm/integration/service/EnterpriseService.java`

**Method: searchLocalEnterprise**

```java
public SearchResult searchLocalEnterprise(String keyword, int page, int pageSize, String organizationId) {
    // Parameter validation
    if (StringUtils.isBlank(keyword) || keyword.trim().length() < 2) {
        return SearchResult.error("搜索关键词至少需要2个字符");
    }

    int safePage = Math.max(page, 1);
    int safePageSize = pageSize > 0 ? Math.min(pageSize, 50) : 10;

    List<EnterpriseItem> items = new ArrayList<>();

    // Query local database with SQL pagination
    if (StringUtils.isNotBlank(organizationId)) {
        // Calculate offset
        int offset = (safePage - 1) * safePageSize;
        
        // Get total count
        int totalCount = extEnterpriseProfileMapper.countByCompanyName(keyword, organizationId);
        
        // Get paginated results
        List<EnterpriseProfile> localProfiles = extEnterpriseProfileMapper.searchByCompanyName(
            keyword, organizationId, offset, safePageSize
        );
        
        if (localProfiles != null && !localProfiles.isEmpty()) {
            log.info("本地搜索 '{}' 找到 {} 条记录 (第{}页)", keyword, totalCount, safePage);
            
            for (EnterpriseProfile profile : localProfiles) {
                items.add(toLocalEnterpriseItem(profile));
            }
        }
        
        return SearchResult.success(items, totalCount);
    }

    // No organization ID, return empty
    return SearchResult.success(items, 0);
}
```

**Method: searchEnterprise (Hybrid Search)**

```java
public SearchResult searchEnterprise(String keyword, int page, int pageSize, String organizationId) {
    // Parameter validation
    if (StringUtils.isBlank(keyword) || keyword.trim().length() < 2) {
        return SearchResult.error("搜索关键词至少需要2个字符");
    }

    int safePage = Math.max(page, 1);
    int safePageSize = pageSize > 0 ? Math.min(pageSize, 50) : 10;

    List<EnterpriseItem> items = new ArrayList<>();
    Set<String> seenCreditCodes = new HashSet<>();

    // 1. Fetch local results for this page
    if (StringUtils.isNotBlank(organizationId)) {
        int offset = (safePage - 1) * safePageSize;
        List<EnterpriseProfile> localProfiles = extEnterpriseProfileMapper.searchByCompanyName(
            keyword, organizationId, offset, safePageSize
        );
        
        if (localProfiles != null && !localProfiles.isEmpty()) {
            log.info("本地搜索 '{}' 第{}页找到 {} 条记录", keyword, safePage, localProfiles.size());
            
            for (EnterpriseProfile profile : localProfiles) {
                EnterpriseItem item = toLocalEnterpriseItem(profile);
                items.add(item);
                
                // Track credit codes for deduplication
                if (StringUtils.isNotBlank(item.getCreditCode())) {
                    seenCreditCodes.add(item.getCreditCode());
                }
            }
        }
    }

    // 2. Fetch remote results for this page
    SearchResult remote = iqichaSearchService.searchEnterprise(keyword, safePage, safePageSize);
    
    if (remote != null && remote.isSuccess() && remote.getItems() != null) {
        log.info("远程搜索 '{}' 第{}页找到 {} 条记录", keyword, safePage, remote.getItems().size());
        
        for (EnterpriseItem remoteItem : remote.getItems()) {
            // Deduplicate by credit code (local takes precedence)
            String creditCode = remoteItem.getCreditCode();
            if (StringUtils.isNotBlank(creditCode) && seenCreditCodes.contains(creditCode)) {
                log.debug("跳过重复企业: {} ({})", remoteItem.getName(), creditCode);
                continue;
            }
            
            items.add(remoteItem);
            if (StringUtils.isNotBlank(creditCode)) {
                seenCreditCodes.add(creditCode);
            }
        }
        
        // Use remote total as the overall total (remote usually has more data)
        int totalCount = Math.max(items.size(), remote.getTotal());
        return SearchResult.success(items, totalCount);
    } else if (remote != null && !remote.isSuccess()) {
        // Remote failed but we have local results
        if (!items.isEmpty()) {
            log.warn("远程搜索失败，返回本地结果: {}", remote.getMessage());
            return SearchResult.success(items, items.size());
        }
        return remote;
    }

    // Only local results
    return SearchResult.success(items, items.size());
}
```

## Data Models

No changes to existing data models. The `SearchResult` and `EnterpriseItem` classes remain unchanged.

## Correctness Properties

### Acceptance Criteria Testing Prework

**1.1 WHEN a user searches for enterprises, THE System SHALL NOT impose any hardcoded limit**
- Thoughts: This is about removing the LIMIT 50 constraint. We can test by inserting 100 records and verifying all are accessible through pagination.
- Testable: yes - property

**1.2 WHEN the database contains more than 50 matching records, THE System SHALL allow users to access all records**
- Thoughts: This is the core bug fix. We can test by creating 60 records and verifying page 6 returns records 51-60.
- Testable: yes - property

**1.3 WHEN a user requests page N, THE System SHALL return records from position (N-1)*pageSize to N*pageSize**
- Thoughts: This is testing pagination math. For any page N and size S, offset should be (N-1)*S and limit should be S.
- Testable: yes - property

**2.1 WHEN executing a search query, THE Mapper SHALL use SQL LIMIT with offset and size**
- Thoughts: This is an implementation detail we can verify by checking the SQL query structure.
- Testable: yes - example

**2.2 WHEN calculating pagination, THE Service SHALL pass offset and limit to the database**
- Thoughts: This is testing that offset = (page-1)*size is calculated correctly.
- Testable: yes - property

**2.3 WHEN fetching results, THE System SHALL NOT load all matching records into memory**
- Thoughts: This is a performance/implementation constraint. We verify by checking the SQL uses LIMIT.
- Testable: yes - example

**3.1 WHEN executing a search, THE System SHALL query the total count**
- Thoughts: This is testing that countByCompanyName is called and returns accurate results.
- Testable: yes - property

**3.2 WHEN returning search results, THE System SHALL include the total count**
- Thoughts: This is testing that SearchResult contains the total field.
- Testable: yes - example

**3.3 WHEN the count query executes, THE System SHALL use the same filter criteria**
- Thoughts: This is testing that count and search queries use the same WHERE clause.
- Testable: yes - property

**4.1 WHEN executing hybrid search on page 1, THE System SHALL fetch local and supplement with remote**
- Thoughts: This is testing the page 1 hybrid logic. We can verify local results are fetched first.
- Testable: yes - property

**4.2 WHEN executing hybrid search on page N (N > 1), THE System SHALL fetch both local and remote**
- Thoughts: This is testing that both sources are queried for any page.
- Testable: yes - property

**4.3 WHEN merging results, THE System SHALL deduplicate by credit code with local precedence**
- Thoughts: This is testing deduplication logic. For any two items with same credit code, local should be kept.
- Testable: yes - property

**4.4 WHEN local results are empty, THE System SHALL return remote results**
- Thoughts: This is testing fallback behavior when local has no matches.
- Testable: yes - example

**7.1 WHEN browsing consecutive pages, THE System SHALL NOT show duplicates**
- Thoughts: This is testing pagination consistency. Union of all pages should have no duplicates.
- Testable: yes - property

**7.2 WHEN browsing all pages, THE System SHALL show every record exactly once**
- Thoughts: This is testing completeness. Union of all pages should equal the full result set.
- Testable: yes - property

### Property Reflection

After reviewing the prework, I identify the following consolidations:

- Properties 1.1, 1.2, 1.3 all test pagination completeness → Combine into Property 1
- Properties 2.1, 2.2, 2.3 all test SQL pagination implementation → Combine into Property 2
- Properties 3.1, 3.2, 3.3 all test count accuracy → Combine into Property 3
- Properties 4.1, 4.2, 4.3, 4.4 all test hybrid search → Keep as separate properties (4, 5, 6)
- Properties 7.1, 7.2 test pagination consistency → Combine into Property 7

### Correctness Properties

A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.

**Property 1: Pagination Completeness**

*For any* search keyword that matches N records in the database, paginating through all pages with size S should allow access to all N records, with no record appearing beyond page ceil(N/S).

**Validates: Requirements 1.1, 1.2, 1.3**

**Property 2: SQL-Level Pagination**

*For any* search request with page P and size S, the Mapper SHALL be called with offset = (P-1)*S and limit = S, and the SQL query SHALL use these parameters in the LIMIT clause.

**Validates: Requirements 2.1, 2.2, 2.3**

**Property 3: Count Accuracy**

*For any* search keyword, the count returned by countByCompanyName SHALL equal the total number of records that would be returned by searchByCompanyName without pagination (i.e., with no LIMIT clause).

**Validates: Requirements 3.1, 3.2, 3.3**

**Property 4: Hybrid Search Deduplication**

*For any* search keyword on page P, if both local and remote sources return items with the same credit code, the merged result SHALL contain only the local item (local takes precedence).

**Validates: Requirements 4.3**

**Property 5: Hybrid Search Completeness**

*For any* search keyword on page P, the hybrid search SHALL fetch both local page P and remote page P, ensuring no data source is skipped.

**Validates: Requirements 4.2**

**Property 6: Hybrid Search Fallback**

*For any* search keyword on page P, if local search returns empty results, the hybrid search SHALL return remote results for that page.

**Validates: Requirements 4.4**

**Property 7: Pagination Consistency**

*For any* search keyword, browsing through all pages sequentially SHALL show each matching record exactly once, with no duplicates and no missing records.

**Validates: Requirements 7.1, 7.2**

**Property 8: Performance Boundary**

*For any* search keyword matching up to 10,000 records, the search query SHALL complete within 2 seconds, demonstrating that SQL pagination maintains acceptable performance.

**Validates: Requirements 5.1**

## Error Handling

### Invalid Parameters
- Empty or null keyword → Return error "搜索关键词至少需要2个字符"
- Page < 1 → Normalize to page 1
- PageSize < 1 → Normalize to default (10)
- PageSize > 50 → Cap at 50

### Database Errors
- SQL exception → Log error and return SearchResult.error()
- Connection timeout → Retry once, then return error

### Remote Search Failures
- Remote API unavailable → Return local results with warning
- Remote API timeout → Return local results with warning
- Remote API error → Return local results with warning

## Testing Strategy

### Dual Testing Approach

This feature requires both unit tests and property-based tests:

- **Unit tests**: Verify specific examples, edge cases, and error conditions
- **Property tests**: Verify universal properties across all inputs
- Both are complementary and necessary for comprehensive coverage

### Unit Testing

Unit tests focus on specific scenarios and edge cases:

1. **Empty Results**: Search with no matches returns empty list with count 0
2. **Single Page**: Search with 5 results and pageSize 10 returns all 5 on page 1
3. **Exact Page Boundary**: Search with 10 results and pageSize 10 returns all on page 1, page 2 is empty
4. **Error Cases**: Invalid parameters return appropriate errors
5. **Remote Failure**: Hybrid search returns local results when remote fails

### Property-Based Testing

Property tests verify universal correctness across many generated inputs:

**Configuration**: Each property test MUST run minimum 100 iterations.

**Test 1: Pagination Completeness Property**
```java
@Property(tries = 100)
void paginationCompleteness(@ForAll @IntRange(min = 1, max = 200) int totalRecords,
                            @ForAll @IntRange(min = 1, max = 50) int pageSize) {
    // Setup: Insert totalRecords into database
    // Execute: Paginate through all pages
    // Verify: Union of all pages contains exactly totalRecords unique items
}
```
**Feature: enterprise-search-pagination, Property 1: Pagination Completeness**

**Test 2: SQL Pagination Property**
```java
@Property(tries = 100)
void sqlPaginationParameters(@ForAll @IntRange(min = 1, max = 100) int page,
                             @ForAll @IntRange(min = 1, max = 50) int size) {
    // Execute: Call searchLocalEnterprise(keyword, page, size, orgId)
    // Verify: Mapper was called with offset = (page-1)*size and limit = size
}
```
**Feature: enterprise-search-pagination, Property 2: SQL-Level Pagination**

**Test 3: Count Accuracy Property**
```java
@Property(tries = 100)
void countAccuracy(@ForAll String keyword) {
    // Setup: Insert random number of matching records
    // Execute: Call countByCompanyName and searchByCompanyName (no limit)
    // Verify: Count equals the size of the full result list
}
```
**Feature: enterprise-search-pagination, Property 3: Count Accuracy**

**Test 4: Hybrid Deduplication Property**
```java
@Property(tries = 100)
void hybridDeduplication(@ForAll List<EnterpriseProfile> localItems,
                         @ForAll List<EnterpriseItem> remoteItems) {
    // Setup: Ensure some items have overlapping credit codes
    // Execute: Call searchEnterprise (hybrid)
    // Verify: Result contains no duplicate credit codes
    // Verify: For duplicates, local version is present
}
```
**Feature: enterprise-search-pagination, Property 4: Hybrid Search Deduplication**

**Test 5: Pagination Consistency Property**
```java
@Property(tries = 100)
void paginationConsistency(@ForAll @IntRange(min = 10, max = 100) int totalRecords,
                           @ForAll @IntRange(min = 5, max = 20) int pageSize) {
    // Setup: Insert totalRecords
    // Execute: Fetch all pages sequentially
    // Verify: No record appears twice
    // Verify: Every record appears exactly once
}
```
**Feature: enterprise-search-pagination, Property 7: Pagination Consistency**

### Integration Testing

Integration tests verify the full stack:

1. **End-to-End Pagination**: Insert 60 records, verify page 6 returns records 51-60
2. **Hybrid Search Flow**: Verify local and remote results are merged correctly
3. **Performance Test**: Verify 10,000 records can be searched within 2 seconds

## Performance Considerations

### Database Indexes

Ensure the following indexes exist:

```sql
CREATE INDEX idx_enterprise_profile_company_name ON enterprise_profile(company_name, organization_id);
CREATE INDEX idx_enterprise_profile_org_create ON enterprise_profile(organization_id, create_time DESC);
```

### Query Optimization

- Use `LIMIT offset, size` for efficient pagination
- Use `COUNT(*)` with same WHERE clause for accurate totals
- Avoid `SELECT *` if only specific fields are needed

### Caching Strategy

Consider caching:
- Total count for frequently searched keywords (TTL: 5 minutes)
- First page results for popular searches (TTL: 1 minute)

## Migration Strategy

### Phase 1: Mapper Layer (Low Risk)
1. Add new methods with pagination parameters
2. Keep old methods for backward compatibility
3. Update XML with new queries

### Phase 2: Service Layer (Medium Risk)
1. Update `searchLocalEnterprise` to use new Mapper methods
2. Update `searchEnterprise` hybrid logic
3. Test thoroughly with existing data

### Phase 3: Deprecation (Future)
1. Mark old Mapper methods as @Deprecated
2. Remove after confirming no usages

## Rollback Plan

If issues are discovered:
1. Revert Service layer changes (restore old pagination logic)
2. Keep new Mapper methods (they don't break anything)
3. Investigate and fix issues
4. Redeploy with fixes

## Monitoring

Add logging for:
- Search query execution time
- Page requests beyond page 5 (indicates users are browsing deep)
- Hybrid search merge statistics (local vs remote counts)
- Count query execution time
