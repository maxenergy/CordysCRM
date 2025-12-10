# 任务完成工作流规则

## 任务完成后的必要步骤

每次完成一个任务（例如 `[x] 13. 实现 Content Script`）后，必须执行以下步骤：

### 1. Codex MCP 代码审核

在任务完成后，必须调用 Codex MCP 进行代码审核：

```
使用 codex MCP 工具，sandbox="read-only"
请求 codex 审核本次任务的代码改动和需求完成程度
```

### 2. 编译验证

根据项目类型执行相应的编译/分析命令：

- **Flutter 项目**: `flutter analyze` 和 `flutter test`
- **Java 项目**: `mvn compile` 或 `mvn test`
- **TypeScript 项目**: `npm run build` 或 `pnpm build`

### 3. Git 提交

编译通过后，必须提交代码到 Git：

```bash
git add .
git commit -m "feat(模块名): 完成任务描述"
```

提交信息格式：
- `feat(flutter): 完成本地数据库实现 (Task 18)`
- `feat(chrome-extension): 实现 Content Script (Task 13)`
- `fix(backend): 修复企业去重逻辑`

### 4. 工作流程总结

```
任务开发 → Codex 审核 → 编译验证 → Git 提交 → 下一个任务
```

## 注意事项

- 每个 Checkpoint 任务完成后也需要提交 Git
- 提交信息应该清晰描述本次改动的内容
- 如果编译失败，先修复问题再提交
