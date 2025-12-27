# Requirements Document: Enterprise Search SQL Pagination Fix

## Introduction

The current enterprise search implementation has a critical data accessibility bug where users cannot access records beyond the first 50 results. The SQL query in `ExtEnterpriseProfileMapper.xml` has a hardcoded `LIMIT 50`, and the Service layer performs in-memory pagination on this truncated dataset. This means if a search matches 100 records, users can only ever see the first 50, with pages requesting records 51+ returning empty results.

This specification addresses this P0 issue by implementing proper SQL-level pagination.

## Glossary

- **Enterprise_Profile**: Database table storing imported enterprise information
- **Local_Search**: Search against the local enterprise_profile database
- **Remote_Search**: Search against external data sources (Iqicha/Aiqicha)
- **Hybrid_Search**: Combined search strategy using both local and remote sources
- **SQL_Pagination**: Database-level pagination using LIMIT offset, size
- **Memory_Pagination**: Application-level pagination using List.subList()

## Requirements

### Requirement 1: Remove Hardcoded Limits

**User Story:** As a sales person, I want to search for enterprises and see all matching results in my database, not just the first 50 records, so that I can find specific customers I've imported.

#### Acceptance Criteria

1. WHEN a user searches for enterprises, THE System SHALL NOT impose any hardcoded limit on the number of accessible results
2. WHEN the database contains more than 50 matching records, THE System SHALL allow users to access all records through pagination
3. WHEN a user requests page N of search results, THE System SHALL return records from position (N-1)*pageSize to N*pageSize

### Requirement 2: SQL-Level Pagination

**User Story:** As a system administrator, I want search queries to use database-level pagination, so that memory usage remains controlled even with large result sets.

#### Acceptance Criteria

1. WHEN executing a search query, THE Mapper SHALL use SQL LIMIT with offset and size parameters
2. WHEN calculating pagination, THE Service SHALL pass offset and limit to the database layer
3. WHEN fetching results, THE System SHALL NOT load all matching records into memory before pagination

### Requirement 3: Accurate Result Counts

**User Story:** As a user, I want to see the total number of matching results, so that I know how many pages are available.

#### Acceptance Criteria

1. WHEN executing a search, THE System SHALL query the total count of matching records
2. WHEN returning search results, THE System SHALL include the total count in the response
3. WHEN the count query executes, THE System SHALL use the same filter criteria as the data query

### Requirement 4: Hybrid Search Compatibility

**User Story:** As a user, I want hybrid search (local + remote) to work correctly with pagination, so that I can see both my imported data and discover new enterprises.

#### Acceptance Criteria

1. WHEN executing hybrid search on page 1, THE System SHALL fetch local results and supplement with remote results if needed
2. WHEN executing hybrid search on page N (N > 1), THE System SHALL fetch both local page N and remote page N
3. WHEN merging local and remote results, THE System SHALL deduplicate by credit code with local results taking precedence
4. WHEN local results are empty for a page, THE System SHALL return remote results for that page

### Requirement 5: Performance Optimization

**User Story:** As a system administrator, I want search performance to remain acceptable even with thousands of records, so that users have a responsive experience.

#### Acceptance Criteria

1. WHEN searching with large result sets (>1000 records), THE System SHALL maintain response times under 2 seconds
2. WHEN executing pagination queries, THE System SHALL use database indexes on company_name and organization_id
3. WHEN fetching a specific page, THE System SHALL NOT scan records from previous pages

### Requirement 6: Backward Compatibility

**User Story:** As a developer, I want the API contract to remain stable, so that existing clients continue to work without modification.

#### Acceptance Criteria

1. WHEN clients call searchLocalEnterprise, THE System SHALL return SearchResult with the same structure
2. WHEN clients call searchEnterprise, THE System SHALL return SearchResult with the same structure
3. WHEN the response format changes, THE System SHALL maintain backward compatibility with existing fields

### Requirement 7: Data Integrity

**User Story:** As a user, I want pagination to be consistent, so that I don't see duplicate records or miss records when browsing pages.

#### Acceptance Criteria

1. WHEN browsing consecutive pages, THE System SHALL NOT show the same record on multiple pages
2. WHEN browsing all pages sequentially, THE System SHALL show every matching record exactly once
3. WHEN the result set changes during pagination, THE System SHALL handle it gracefully without errors

### Requirement 8: Error Handling

**User Story:** As a user, I want clear error messages when search fails, so that I understand what went wrong.

#### Acceptance Criteria

1. WHEN a search query fails, THE System SHALL return a descriptive error message
2. WHEN remote search fails during hybrid search, THE System SHALL return local results with a warning
3. WHEN invalid pagination parameters are provided, THE System SHALL return a validation error

## Non-Functional Requirements

### Performance
- Search queries SHALL complete within 2 seconds for result sets up to 10,000 records
- Count queries SHALL complete within 500ms

### Scalability
- The system SHALL support pagination of result sets up to 100,000 records
- Memory usage SHALL remain constant regardless of result set size

### Maintainability
- SQL queries SHALL be parameterized to prevent SQL injection
- Pagination logic SHALL be centralized in the Mapper layer
