# Requirements Document

## Introduction

本功能为 CordysCRM Flutter 移动应用的企业搜索页面增加"重新搜索"功能。当搜索结果来自 CRM 本地数据库时，用户可以点击"重新搜索"按钮，从外部数据源（企查查/爱企查）搜索相同关键词，并将外部结果追加到本地结果之后显示。

这个功能解决了以下场景：用户搜索"网杰"，CRM 本地库中已有一条"网杰"的记录，但用户想查看企查查上所有名称包含"网杰"的企业，以便发现更多潜在客户。

## Glossary

- **Enterprise_Search_Page**: 企业搜索页面，用于搜索和展示企业信息
- **Local_Search**: 从 CRM 本地数据库搜索企业
- **External_Search**: 从外部数据源（企查查/爱企查）搜索企业
- **Re_Search**: 重新搜索功能，在本地结果基础上追加外部搜索结果
- **Mixed_Results**: 混合结果，包含本地和外部数据源的企业信息
- **Data_Source_Banner**: 数据来源横幅，显示当前结果的来源

## Requirements

### Requirement 1: Re-Search Button Display

**User Story:** As a sales representative, I want to see a "Re-search" button when search results come from local database, so that I can search for more enterprises from external sources.

#### Acceptance Criteria

1. WHEN search results come from CRM local database THEN the Enterprise_Search_Page SHALL display a "重新搜索" button in the Data_Source_Banner
2. WHEN search results come from external sources (QCC or Aiqicha) THEN the Enterprise_Search_Page SHALL NOT display the "重新搜索" button
3. WHEN search results are mixed (local + external) THEN the Enterprise_Search_Page SHALL NOT display the "重新搜索" button
4. WHEN no search results are found THEN the Enterprise_Search_Page SHALL NOT display the "重新搜索" button

### Requirement 2: Re-Search Execution

**User Story:** As a sales representative, I want to click the "Re-search" button to search external sources, so that I can find more enterprises with the same keyword.

#### Acceptance Criteria

1. WHEN user taps the "重新搜索" button THEN the system SHALL search the current external data source (QCC or Aiqicha) using the same keyword
2. WHILE Re_Search is in progress THEN the system SHALL display a loading indicator on the button
3. WHEN Re_Search completes successfully THEN the system SHALL append external results after local results
4. WHEN Re_Search completes THEN the system SHALL update the data source to "mixed"
5. IF Re_Search fails THEN the system SHALL display an error message without clearing local results
6. IF Re_Search completes successfully but finds no new external results THEN the system SHALL display a temporary notification (e.g., a SnackBar) informing the user that no new results were found, and the result list SHALL remain unchanged

### Requirement 3: Mixed Results Display

**User Story:** As a sales representative, I want to see both local and external results clearly distinguished, so that I can understand where each enterprise comes from.

#### Acceptance Criteria

1. WHEN displaying mixed results THEN the Enterprise_Search_Page SHALL show local results first, followed by external results
2. WHEN displaying mixed results THEN the Data_Source_Banner SHALL indicate "本地 + 企查查" or "本地 + 爱企查"
3. WHEN displaying mixed results THEN each Enterprise_Search_Result_Item SHALL show its source (本地/企查查/爱企查) via the source chip
4. WHEN merging results THEN the system SHALL remove external results that are duplicates of local results. Duplicates are identified by their unique `creditCode`. The local version of the record SHALL always be preserved

### Requirement 4: State Preservation

**User Story:** As a sales representative, I want my local results preserved when re-searching, so that I don't lose the original search results.

#### Acceptance Criteria

1. WHEN Re_Search is triggered THEN the system SHALL preserve existing local results
2. WHEN Re_Search fails THEN the system SHALL keep the original local results unchanged
3. WHEN user clears the search THEN the system SHALL clear all results (both local and external)

### Requirement 5: Granular Error Handling

**User Story:** As a sales representative, when a re-search fails, I want to know why it failed and what I can do next, so I can resolve the issue myself.

#### Acceptance Criteria

1. WHEN re-search fails due to the external source requiring login THEN the system SHALL display a message explaining this and provide a shortcut to navigate to the login page
2. WHEN re-search fails due to network issues or timeouts THEN the system SHALL display a corresponding error message
3. WHEN re-search fails because the search engine is not ready THEN the system SHALL instruct the user to initialize it first
