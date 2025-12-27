# Implementation Plan: Enterprise Search SQL Pagination Fix

## Overview

This implementation plan addresses the P0 data accessibility bug where users cannot access enterprise search results beyond the first 50 records. The fix involves implementing SQL-level pagination in the Mapper layer and updating the Service layer to use it correctly.

## Tasks

- [ ] 1. Phase 1: Mapper Layer - Add SQL Pagination Support
  - Update ExtEnterpriseProfileMapper interface and XML to support pagination
  - Add count query for accurate total counts
  - _Requirements: 1.1, 1.2, 1.3, 2.1, 2.2, 2.3, 3.1, 3.2, 3.3_

- [ ] 1.1 Update ExtEnterpriseProfileMapper.java interface
  - Modify `searchByCompanyName` method signature to add `offset` and `limit` parameters
  - Add new `countByCompanyName` method
  - _Requirements: 2.1, 3.1_

- [ ] 1.2 Update ExtEnterpriseProfileMapper.xml SQL queries
  - Modify `searchByCompanyName` query to use `LIMIT #{offset}, #{limit}` instead of `LIMIT 50`
  - Add `countByCompanyName` query with same WHERE clause as search query
  - _Requirements: 2.1, 3.1, 3.3_

- [ ]* 1.3 Write unit tests for Mapper layer
  - Test `searchByCompanyName` with various offset/limit combinations
  - Test `countByCompanyName` returns accurate counts
  - Test edge cases (offset beyond total, limit 0, etc.)
  - _Requirements: 2.1, 3.1_

- [ ] 2. Phase 2: Service Layer - Update Pagination Logic
  - Update EnterpriseService to use SQL pagination instead of memory pagination
  - Update hybrid search logic to fetch both local and remote for all pages
  - _Requirements: 1.1, 1.2, 1.3, 4.1, 4.2, 4.3, 4.4_

- [ ] 2.1 Update searchLocalEnterprise method
  - Calculate `offset = (page - 1) * pageSize`
  - Call `countByCompanyName` to get total count
  - Call `searchByCompanyName` with offset and limit
  - Remove in-memory `subList` pagination
  - Return `SearchResult.success(items, totalCount)`
  - _Requirements: 1.1, 1.2, 1.3, 2.2, 3.2_

- [ ] 2.2 Update searchEnterprise method (hybrid search)
  - Remove `if (safePage > 1) return remote` logic
  - Fetch local results for page N using SQL pagination
  - Fetch remote results for page N
  - Merge and deduplicate by credit code (local takes precedence)
  - Return merged results with appropriate total count
  - _Requirements: 4.1, 4.2, 4.3, 4.4_

- [ ]* 2.3 Write unit tests for Service layer
  - Test `searchLocalEnterprise` with various page/size combinations
  - Test `searchEnterprise` hybrid logic with mock local and remote data
  - Test deduplication logic
  - Test error handling (remote failure, invalid parameters)
  - _Requirements: 1.1, 4.3, 8.1, 8.2_

- [ ] 3. Checkpoint - Verify Core Functionality
  - Ensure all tests pass
  - Manually test with > 50 records in database
  - Verify page 6 returns records 51-60
  - Ask the user if questions arise

- [ ] 4. Phase 3: Property-Based Testing
  - Implement property tests to verify universal correctness
  - Run tests with minimum 100 iterations each
  - _Requirements: 1.1, 1.2, 1.3, 7.1, 7.2_

- [ ]* 4.1 Write property test for Pagination Completeness
  - **Property 1: Pagination Completeness**
  - **Validates: Requirements 1.1, 1.2, 1.3**
  - Generate random total records (1-200) and page size (1-50)
  - Insert records into test database
  - Paginate through all pages
  - Verify union of all pages contains exactly totalRecords unique items
  - _Requirements: 1.1, 1.2, 1.3_

- [ ]* 4.2 Write property test for SQL Pagination Parameters
  - **Property 2: SQL-Level Pagination**
  - **Validates: Requirements 2.1, 2.2, 2.3**
  - Generate random page (1-100) and size (1-50)
  - Call searchLocalEnterprise
  - Verify Mapper was called with offset = (page-1)*size and limit = size
  - _Requirements: 2.1, 2.2_

- [ ]* 4.3 Write property test for Count Accuracy
  - **Property 3: Count Accuracy**
  - **Validates: Requirements 3.1, 3.2, 3.3**
  - Generate random keyword and matching records
  - Call countByCompanyName and searchByCompanyName (no limit)
  - Verify count equals the size of the full result list
  - _Requirements: 3.1, 3.2, 3.3_

- [ ]* 4.4 Write property test for Hybrid Deduplication
  - **Property 4: Hybrid Search Deduplication**
  - **Validates: Requirements 4.3**
  - Generate random local and remote items with overlapping credit codes
  - Call searchEnterprise (hybrid)
  - Verify result contains no duplicate credit codes
  - Verify for duplicates, local version is present
  - _Requirements: 4.3_

- [ ]* 4.5 Write property test for Pagination Consistency
  - **Property 7: Pagination Consistency**
  - **Validates: Requirements 7.1, 7.2**
  - Generate random total records (10-100) and page size (5-20)
  - Insert records into test database
  - Fetch all pages sequentially
  - Verify no record appears twice
  - Verify every record appears exactly once
  - _Requirements: 7.1, 7.2_

- [ ] 5. Checkpoint - Verify Property Tests
  - Ensure all property tests pass with 100+ iterations
  - Review any failing test cases
  - Ask the user if questions arise

- [ ] 6. Phase 4: Integration Testing
  - Test end-to-end with real database
  - Verify performance with large datasets
  - _Requirements: 5.1, 5.2, 5.3_

- [ ]* 6.1 Create integration test with 60 records
  - Insert 60 test enterprise records with similar names
  - Search for keyword matching all 60
  - Request page 1 (size 10): verify returns records 1-10
  - Request page 6 (size 10): verify returns records 51-60
  - Request page 7 (size 10): verify returns empty
  - _Requirements: 1.2, 1.3_

- [ ]* 6.2 Create integration test for hybrid search
  - Mock local database with 15 records
  - Mock remote service with 20 records (5 overlapping credit codes)
  - Request page 1: verify local + remote merged correctly
  - Request page 2: verify local + remote merged correctly
  - Verify deduplication worked (local took precedence)
  - _Requirements: 4.1, 4.2, 4.3_

- [ ]* 6.3 Create performance test with 10,000 records
  - Insert 10,000 test records
  - Search with keyword matching all 10,000
  - Request page 1: measure response time (should be < 2s)
  - Request page 500: measure response time (should be < 2s)
  - Verify memory usage remains constant
  - _Requirements: 5.1, 5.2, 5.3_

- [ ] 7. Final Checkpoint - Production Readiness
  - All tests pass (unit, property, integration)
  - Code review completed
  - Performance benchmarks met
  - Documentation updated
  - Ask the user if ready for deployment

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties
- Unit tests validate specific examples and edge cases
- Integration tests validate end-to-end functionality

## Implementation Order

1. **Phase 1** (Mapper): Low risk, foundational changes
2. **Phase 2** (Service): Medium risk, core business logic
3. **Checkpoint**: Verify basic functionality works
4. **Phase 3** (Property Tests): High value, catch edge cases
5. **Checkpoint**: Verify properties hold
6. **Phase 4** (Integration): Verify real-world scenarios
7. **Final Checkpoint**: Production readiness

## Rollback Strategy

If issues are discovered during implementation:
1. Phase 1 changes are safe (new methods don't break existing code)
2. Phase 2 changes can be reverted by restoring old Service methods
3. Tests can be disabled temporarily if blocking deployment
4. Monitor production logs for any pagination issues after deployment
