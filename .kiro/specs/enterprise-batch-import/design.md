# Design Document

## Overview

本设计为 Flutter 企业搜索页面添加多选、全选和批量导入功能。采用状态驱动的 UI 设计，通过 Riverpod 管理选择状态，使用底部选择栏提供操作入口，通过进度对话框展示批量导入进度。

## Architecture

### Component Structure

```
EnterpriseSearchPage (UI)
├── EnterpriseSearchResultItem (带复选框)
├── SelectionBar (底部选择栏)
└── BatchImportProgressDialog (进度对话框)

EnterpriseSearchNotifier (State Management)
├── Selection State (选择状态)
├── Batch Import Logic (批量导入逻辑)
└── Progress Tracking (进度跟踪)

EnterpriseRepository (Data Layer)
└── importEnterprise() (单个导入，循环调用)
```

### State Flow

```
Normal Mode → Long Press → Selection Mode
                              ↓
                         Select Items
                              ↓
                      Tap Batch Import
                              ↓
                      Show Confirmation
                              ↓
                      Import Sequentially
                              ↓
                      Show Progress
                              ↓
                      Show Summary
                              ↓
                      Exit Selection Mode
```

## Components and Interfaces

### 1. EnterpriseSearchState Extension

扩展现有的 `EnterpriseSearchState` 类，添加选择模式相关字段：

```dart
class EnterpriseSearchState {
  // 现有字段...
  
  // 新增字段
  final bool isSelectionMode;           // 是否处于选择模式
  final Set<String> selectedIds;        // 已选企业ID集合（使用creditCode）
  final bool isBatchImporting;          // 是否正在批量导入
  final int importProgress;             // 当前导入进度（已完成数量）
  final int importTotal;                // 总导入数量
  final List<BatchImportError> importErrors; // 导入失败的企业列表
  
  // Getters
  int get selectedCount => selectedIds.length;
  bool get hasSelection => selectedIds.isNotEmpty;
  bool get canBatchImport => isSelectionMode && hasSelection && !isBatchImporting;
  bool get isAllSelected => results.where((e) => !e.isLocal).every((e) => selectedIds.contains(e.creditCode));
  List<Enterprise> get selectedEnterprises => results.where((e) => selectedIds.contains(e.creditCode)).toList();
}

class BatchImportError {
  final Enterprise enterprise;
  final String error;
  
  const BatchImportError({required this.enterprise, required this.error});
}
```

### 2. EnterpriseSearchNotifier Methods

添加选择模式和批量导入相关方法：

```dart
class EnterpriseSearchNotifier extends StateNotifier<EnterpriseSearchState> {
  // 进入选择模式
  void enterSelectionMode(String initialSelectedId) {
    state = state.copyWith(
      isSelectionMode: true,
      selectedIds: {initialSelectedId},
    );
  }
  
  // 退出选择模式
  void exitSelectionMode() {
    state = state.copyWith(
      isSelectionMode: false,
      selectedIds: <String>{},
      clearImportErrors: true,
    );
  }
  
  // 切换选择状态
  void toggleSelection(String creditCode) {
    final enterprise = state.results.firstWhere((e) => e.creditCode == creditCode);
    
    // 本地企业不可选
    if (enterprise.isLocal) {
      // 触发 toast 提示
      return;
    }
    
    final newSelectedIds = Set<String>.from(state.selectedIds);
    if (newSelectedIds.contains(creditCode)) {
      newSelectedIds.remove(creditCode);
    } else {
      // 检查是否达到上限
      if (newSelectedIds.length >= 50) {
        // 触发 toast 提示
        return;
      }
      newSelectedIds.add(creditCode);
    }
    
    state = state.copyWith(selectedIds: newSelectedIds);
  }
  
  // 全选/取消全选
  void toggleSelectAll() {
    final selectableEnterprises = state.results.where((e) => !e.isLocal).toList();
    
    if (state.isAllSelected) {
      // 取消全选
      state = state.copyWith(selectedIds: <String>{});
    } else {
      // 全选（最多50个）
      final idsToSelect = selectableEnterprises
          .take(50)
          .map((e) => e.creditCode)
          .toSet();
      state = state.copyWith(selectedIds: idsToSelect);
    }
  }
  
  // 批量导入
  Future<void> batchImport() async {
    if (!state.canBatchImport) return;
    
    final enterprises = state.selectedEnterprises;
    final total = enterprises.length;
    
    state = state.copyWith(
      isBatchImporting: true,
      importProgress: 0,
      importTotal: total,
      clearImportErrors: true,
    );
    
    final errors = <BatchImportError>[];
    
    for (int i = 0; i < enterprises.length; i++) {
      final enterprise = enterprises[i];
      
      try {
        final result = await _repository.importEnterprise(
          enterprise: enterprise,
          forceOverwrite: false,
        );
        
        if (!result.isSuccess) {
          errors.add(BatchImportError(
            enterprise: enterprise,
            error: result.message ?? '导入失败',
          ));
        }
      } catch (e) {
        errors.add(BatchImportError(
          enterprise: enterprise,
          error: e.toString(),
        ));
      }
      
      // 更新进度
      if (mounted) {
        state = state.copyWith(importProgress: i + 1);
      }
      
      // 避免请求过快
      await Future.delayed(const Duration(milliseconds: 300));
    }
    
    if (!mounted) return;
    
    state = state.copyWith(
      isBatchImporting: false,
      importErrors: errors,
    );
    
    // 如果全部成功，退出选择模式并刷新
    if (errors.isEmpty) {
      exitSelectionMode();
      // 刷新搜索结果以更新本地状态
      if (state.keyword.isNotEmpty) {
        await search(state.keyword);
      }
    }
  }
}
```

### 3. UI Components

#### SelectionBar Widget

底部选择栏，显示已选数量和操作按钮：

```dart
class SelectionBar extends StatelessWidget {
  final int selectedCount;
  final bool isAllSelected;
  final VoidCallback onCancel;
  final VoidCallback onSelectAll;
  final VoidCallback onBatchImport;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [BoxShadow(...)],
      ),
      child: Row(
        children: [
          TextButton(
            onPressed: onCancel,
            child: Text('取消'),
          ),
          Spacer(),
          Text('已选 $selectedCount'),
          SizedBox(width: 16),
          TextButton(
            onPressed: onSelectAll,
            child: Text(isAllSelected ? '取消全选' : '全选'),
          ),
          SizedBox(width: 8),
          FilledButton(
            onPressed: selectedCount > 0 ? onBatchImport : null,
            child: Text('批量导入 ($selectedCount)'),
          ),
        ],
      ),
    );
  }
}
```

#### BatchImportProgressDialog

批量导入进度对话框：

```dart
class BatchImportProgressDialog extends StatelessWidget {
  final int current;
  final int total;
  
  @override
  Widget build(BuildContext context) {
    final progress = current / total;
    
    return AlertDialog(
      title: Text('正在导入'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: progress),
          SizedBox(height: 16),
          Text('$current / $total'),
        ],
      ),
    );
  }
}
```

#### BatchImportSummaryDialog

批量导入结果摘要对话框：

```dart
class BatchImportSummaryDialog extends StatelessWidget {
  final int successCount;
  final List<BatchImportError> errors;
  
  @override
  Widget build(BuildContext context) {
    final failCount = errors.length;
    final total = successCount + failCount;
    
    return AlertDialog(
      title: Text('导入完成'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('成功: $successCount / $total'),
          if (failCount > 0) ...[
            SizedBox(height: 8),
            Text('失败: $failCount', style: TextStyle(color: Colors.red)),
            SizedBox(height: 8),
            Text('失败企业:', style: TextStyle(fontWeight: FontWeight.bold)),
            ...errors.map((e) => Text('• ${e.enterprise.name}: ${e.error}')),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('确定'),
        ),
      ],
    );
  }
}
```

#### EnterpriseSearchResultItem Modification

修改企业列表项，添加复选框支持：

```dart
class EnterpriseSearchResultItem extends ConsumerWidget {
  final Enterprise enterprise;
  final VoidCallback? onTap;
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectionChanged;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: isSelectionMode ? () => onSelectionChanged?.call(!isSelected) : onTap,
      onLongPress: !isSelectionMode ? () => onLongPress?.call() : null,
      child: Row(
        children: [
          if (isSelectionMode)
            Checkbox(
              value: isSelected,
              onChanged: enterprise.isLocal ? null : onSelectionChanged,
            ),
          Expanded(
            child: // 现有的企业信息展示
          ),
          if (enterprise.isLocal)
            Chip(label: Text('已导入')),
        ],
      ),
    );
  }
}
```

## Data Models

### Enterprise Extension

为 `Enterprise` 实体添加辅助方法：

```dart
extension EnterpriseSelection on Enterprise {
  /// 是否可以被选择（非本地企业）
  bool get isSelectable => !isLocal;
}
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Selection mode toggle consistency

*For any* enterprise search state, entering selection mode should enable checkboxes and show selection bar, and exiting should hide them and clear selections.

**Validates: Requirements 1.2, 1.3, 5.3, 5.4**

### Property 2: Local enterprise exclusion

*For any* enterprise with `isLocal = true`, the checkbox should be disabled and selection attempts should be rejected.

**Validates: Requirements 3.1, 3.2**

### Property 3: Selection limit enforcement

*For any* selection state, the number of selected enterprises should never exceed 50.

**Validates: Requirements 3.3, 3.4**

### Property 4: Batch import progress accuracy

*For any* batch import operation, the progress count should equal the number of completed import attempts (success + failure).

**Validates: Requirements 4.3, 4.4**

### Property 5: Import result consistency

*For any* batch import operation, the sum of success count and failure count should equal the total number of selected enterprises.

**Validates: Requirements 4.5, 4.6**

### Property 6: Selection state preservation during import

*For any* batch import in progress, the selection state should remain unchanged until import completes.

**Validates: Requirements 6.1, 6.2**

### Property 7: Selection clearing on search

*For any* new search operation, if selection mode is active, it should be exited and selections should be cleared.

**Validates: Requirements 6.3, 6.4**

## Error Handling

### Selection Errors

1. **Local Enterprise Selection**: Show toast "该企业已在本地库中"
2. **Selection Limit Reached**: Show toast "最多选择50个企业"
3. **Invalid Selection**: Silently ignore

### Import Errors

1. **Network Error**: Retry once, then add to error list
2. **Duplicate Error**: Add to error list with message
3. **Validation Error**: Add to error list with message
4. **Unknown Error**: Add to error list with generic message

### Error Recovery

- Partial success: Show summary with failed items
- Total failure: Keep selection mode active, allow retry
- Network timeout: Show error dialog, allow retry

## Testing Strategy

### Unit Tests

1. **Selection State Tests**:
   - Test entering/exiting selection mode
   - Test toggling individual selections
   - Test select all/deselect all
   - Test selection limit enforcement
   - Test local enterprise exclusion

2. **Batch Import Tests**:
   - Test sequential import execution
   - Test progress tracking
   - Test error collection
   - Test success/failure counting

3. **UI Component Tests**:
   - Test SelectionBar rendering
   - Test checkbox state synchronization
   - Test dialog display logic

### Property-Based Tests

1. **Property 1-7**: Implement using Flutter's test framework with random state generation
2. **Test Configuration**: Minimum 100 iterations per property
3. **Test Tags**: `Feature: enterprise-batch-import, Property {N}: {description}`

### Integration Tests

1. **End-to-End Flow**:
   - Long press → Select multiple → Batch import → Verify success
   - Test with mixed results (local + external)
   - Test with all external results
   - Test with selection limit

2. **Error Scenarios**:
   - Test with network failures
   - Test with duplicate enterprises
   - Test with partial failures

## Performance Considerations

1. **Sequential Import**: Import one at a time to avoid overwhelming the backend
2. **Delay Between Requests**: 300ms delay to prevent rate limiting
3. **Progress Updates**: Update UI after each import to provide feedback
4. **Memory Management**: Clear selections after successful import

## Accessibility

1. **Checkbox Labels**: Provide semantic labels for screen readers
2. **Selection Feedback**: Announce selection count changes
3. **Progress Feedback**: Announce import progress updates
4. **Error Messages**: Ensure error messages are accessible

