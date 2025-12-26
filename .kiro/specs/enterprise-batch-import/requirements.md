# Requirements Document

## Introduction

本功能为 CordysCRM Flutter 移动应用的企业搜索页面增加多选、全选和批量导入功能。用户可以选择多个企业并一次性批量导入到 CRM 系统，提高工作效率。

这个功能解决了以下场景：销售人员在企查查搜索"科技公司"，返回 20 条结果，用户想一次性导入其中 10 家感兴趣的企业，而不是逐个点击"查看详情"再导入。

## Glossary

- **Enterprise_Search_Page**: 企业搜索页面，用于搜索和展示企业信息
- **Selection_Mode**: 选择模式，允许用户选择多个企业的交互状态
- **Batch_Import**: 批量导入，一次性导入多个选中的企业
- **Selection_Bar**: 选择栏，显示已选数量和操作按钮的底部栏
- **Import_Progress**: 导入进度，显示批量导入的实时进度

## Requirements

### Requirement 1: Enter Selection Mode

**User Story:** As a sales representative, I want to enter selection mode to select multiple enterprises, so that I can batch import them efficiently.

#### Acceptance Criteria

1. WHEN user long-presses an enterprise item THEN the system SHALL enter selection mode
2. WHEN entering selection mode THEN the system SHALL show checkboxes on all enterprise items
3. WHEN entering selection mode THEN the system SHALL show a selection bar at the bottom
4. WHEN entering selection mode THEN the system SHALL automatically select the long-pressed item
5. WHEN in selection mode THEN the system SHALL disable normal tap navigation to detail page

### Requirement 2: Select and Deselect Enterprises

**User Story:** As a sales representative, I want to select and deselect enterprises, so that I can choose which ones to import.

#### Acceptance Criteria

1. WHEN user taps an enterprise item in selection mode THEN the system SHALL toggle its selection state
2. WHEN an enterprise is selected THEN the system SHALL show a checked checkbox
3. WHEN an enterprise is deselected THEN the system SHALL show an unchecked checkbox
4. WHEN selection changes THEN the system SHALL update the selected count in the selection bar
5. WHEN user taps "Select All" button THEN the system SHALL select all enterprises on current page
6. WHEN all enterprises are selected THEN the "Select All" button SHALL change to "Deselect All"
7. WHEN user taps "Deselect All" button THEN the system SHALL deselect all enterprises

### Requirement 3: Selection Constraints

**User Story:** As a sales representative, I want clear feedback on selection constraints, so that I understand what can be selected.

#### Acceptance Criteria

1. WHEN an enterprise is from local database THEN the system SHALL disable its checkbox and show "已导入" badge
2. WHEN user tries to select a local enterprise THEN the system SHALL show a toast message "该企业已在本地库中"
3. WHEN selection count reaches 50 THEN the system SHALL disable unselected checkboxes
4. WHEN selection limit is reached THEN the system SHALL show a toast message "最多选择50个企业"
5. WHEN mixed results (local + external) are displayed THEN the system SHALL only allow selecting external enterprises

### Requirement 4: Batch Import Execution

**User Story:** As a sales representative, I want to batch import selected enterprises, so that I can save time.

#### Acceptance Criteria

1. WHEN user taps "Batch Import" button THEN the system SHALL show a confirmation dialog with selected count
2. WHEN user confirms batch import THEN the system SHALL start importing enterprises sequentially
3. WHILE batch import is in progress THEN the system SHALL show a progress dialog with current/total count
4. WHEN each enterprise is imported THEN the system SHALL update the progress indicator
5. WHEN batch import completes THEN the system SHALL show a summary dialog with success/failure counts
6. IF some imports fail THEN the system SHALL list failed enterprises with error messages
7. WHEN batch import completes successfully THEN the system SHALL exit selection mode and refresh results

### Requirement 5: Exit Selection Mode

**User Story:** As a sales representative, I want to exit selection mode easily, so that I can return to normal browsing.

#### Acceptance Criteria

1. WHEN user taps "Cancel" button in selection bar THEN the system SHALL exit selection mode
2. WHEN user taps back button in selection mode THEN the system SHALL exit selection mode
3. WHEN exiting selection mode THEN the system SHALL clear all selections
4. WHEN exiting selection mode THEN the system SHALL hide checkboxes and selection bar
5. WHEN batch import completes successfully THEN the system SHALL automatically exit selection mode

### Requirement 6: State Preservation

**User Story:** As a sales representative, I want my selections preserved during import, so that I don't lose track of what I selected.

#### Acceptance Criteria

1. WHEN batch import is in progress THEN the system SHALL preserve the selection state
2. WHEN batch import fails THEN the system SHALL keep the selection mode active
3. WHEN user performs a new search THEN the system SHALL exit selection mode and clear selections
4. WHEN user switches data source THEN the system SHALL exit selection mode and clear selections

