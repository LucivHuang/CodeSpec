# Hook Points 扩展

CodeSpec 的核心管线不绑定任何外部系统。如需对接需求管理平台、设计工具、CI/CD 等，通过 Hook Points 在任意核心阶段前/后插入自定义扩展。

## 核心概念

6 个核心阶段编号固定：

| 编号 | 阶段 |
|------|------|
| 1 | 规格生成 |
| 2 | 需求澄清 |
| 3 | 方案设计 |
| 4 | 任务拆解 |
| 5 | 代码实现 |
| 6 | 代码审查 |

扩展通过 `runBefore` 或 `runAfter` 声明执行位置：

```
[前置扩展] → 阶段1 → [扩展] → 阶段2 → [扩展] → ... → 阶段6 → [后置扩展]
```

## 配置方式

在 `.codespec/config/workflow.json` 的 `extensions.stages` 中注册：

```json
{
  "extensions": {
    "stages": [
      {
        "id": "fetch-requirement",
        "name": "从 Jira 获取需求",
        "enabled": true,
        "command": "codespec.fetch-requirement",
        "runBefore": 1,
        "onFailure": "block"
      }
    ]
  }
}
```

### 字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | string | ✅ | 扩展唯一标识符 |
| `name` | string | ✅ | 显示名称 |
| `enabled` | boolean | ✅ | 是否启用 |
| `command` | string | ✅ | `.claude/commands/` 下的命令名 |
| `runBefore` | integer (1-6) | ❌ | 在第 N 个核心阶段之前执行 |
| `runAfter` | integer (1-6) | ❌ | 在第 N 个核心阶段之后执行 |
| `onFailure` | string | ❌ | 失败策略：`block`/`warn`/`skip`（默认 `warn`） |
| `config` | object | ❌ | 传递给扩展的自定义配置 |

**规则**：
- `runBefore` 和 `runAfter` 互斥，同时设置时 `runBefore` 优先
- 都不填时默认 `runAfter: 6`（向后兼容）
- 不合法的值（非 1-6 整数）→ 警告并跳过
- 同一 hook point 有多个扩展时，按数组顺序执行

### 失败策略

| onFailure | 行为 |
|-----------|------|
| `block` | 阻塞，询问用户：重试 / 跳过 / 终止 |
| `warn` | 记录警告，继续后续流程 |
| `skip` | 静默跳过 |

## 常见场景

| 场景 | Hook Point | 说明 |
|------|------------|------|
| 从工单系统获取需求 | `runBefore: 1` | Jira、Linear、飞书项目等 |
| 需求文档转换 | `runBefore: 1` | Confluence、语雀、Notion 等 |
| 设计稿分析 | `runBefore: 1` | Figma、Sketch 等 |
| 方案设计前技术调研 | `runBefore: 3` | 技术选型评估、竞品分析 |
| 实现前环境准备 | `runBefore: 5` | 数据库迁移、环境启动 |
| E2E / 集成测试 | `runAfter: 6` | 审查通过后执行端到端测试 |
| 自动部署 | `runAfter: 6` | 部署到预发/staging 环境 |
| PR / MR 创建 | `runAfter: 6` | 自动创建 Pull Request |

## 编写扩展

### 1. 创建命令文件

在项目的 `.claude/commands/` 目录下创建 `codespec.<ext-id>.md`：

```markdown
---
description: 从 Jira 获取工单详情
---

## 用户输入

\```text
$ARGUMENTS
\```

## 执行步骤

1. 从 $ARGUMENTS 提取工单号
2. 调用 Jira API 获取工单详情
3. 格式化为结构化需求文本
4. 输出 JSON 契约
```

### 2. 输出契约

所有扩展的最后一行必须输出 JSON：

```json
{
  "status": "ok",
  "executedCommand": "codespec.<ext-id>",
  "substituted": false,
  "executionToken": "${CODESPEC_EXECUTION_TOKEN}",
  "evidence": {
    "outputs": ["path/to/output"],
    "notes": "optional note"
  }
}
```

**executionToken 字段（必需）**：
- orchestrator 在调用扩展前会生成唯一令牌并设置环境变量 `CODESPEC_EXECUTION_TOKEN`
- 扩展必须在 JSON 输出中返回该令牌（直接使用 `${CODESPEC_EXECUTION_TOKEN}` 环境变量）
- orchestrator 验证返回的令牌与期望值一致，用于确保扩展确实被执行
- 令牌不匹配或缺失将导致扩展执行失败

### 3. 前置扩展的特殊字段

`runBefore: 1` 的扩展可额外返回 `requirementContent`，orchestrator 会将其作为 Stage 1 的需求输入：

```json
{
  "status": "ok",
  "executedCommand": "codespec.fetch-jira",
  "substituted": false,
  "executionToken": "${CODESPEC_EXECUTION_TOKEN}",
  "requirementContent": "获取到的需求文本...",
  "evidence": {
    "outputs": [],
    "notes": "从 Jira PROJ-123 获取"
  }
}
```

- 若 `requirementContent` 为空或不存在 → Stage 1 回退使用 `$ARGUMENTS` 文本
- 多个 `runBefore: 1` 扩展返回 `requirementContent` → 按数组顺序拼接

### 4. 产物存放

- `runBefore: 1` 的扩展：通过 JSON 契约传递数据（此时 FEATURE_DIR 尚未创建）
- 其他扩展：产物写入 `$FEATURE_DIR/extensions/<ext-id>/`

## 完整示例

扩展命令的编写方式与普通 Claude Code 自定义命令相同，只需确保最后一行输出 JSON 契约即可。参见上方「编写扩展」章节。
