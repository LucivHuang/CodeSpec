# 配置参考

配置文件 `.codespec/config/workflow.json` 可选。不创建则使用全部默认值，零配置即可运行。

## 完整配置示例

```json
{
  "core": {
    "specsDir": ".codespec/specs",
    "language": "zh-CN"
  },
  "project": {
    "branchPattern": "feature/[feature-name]",
    "issueIdPattern": "[A-Z]+-[0-9]+"
  },
  "extensions": {
    "stages": []
  }
}
```

## 配置项说明

### core — 核心配置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `specsDir` | string | `.codespec/specs` | 规格文档存放目录 |
| `language` | string | `zh-CN` | 输出语言（影响所有产物文档和交互提示的语言） |

### project — 项目配置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `branchPattern` | string | `feature/[feature-name]` | 分支命名模式 |
| `issueIdPattern` | string | `[A-Z]+-[0-9]+` | 工单号匹配正则，仅用于从输入中提取 ID 拼入分支名 |

### extensions — 扩展配置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `stages` | object[] | `[]` | 扩展阶段列表。详见 [Hook Points 扩展](hook-points.md) |

## 分支命名模式

`branchPattern` 支持以下占位符：

| 占位符 | 来源 | 说明 |
|--------|------|------|
| `[feature-name]` | 从功能描述自动生成（2-4 词） | 始终存在 |
| `[ISSUE_ID]` | 从输入中用 `issueIdPattern` 提取 | 未找到时占位符及前置分隔符被清除 |

**示例**：

| 输入 | branchPattern | 生成的分支名 |
|------|---------------|-------------|
| `PROJ-123 用户登录` | `feature/[ISSUE_ID]_[feature-name]` | `feature/PROJ-123_user-login` |
| `用户登录` | `feature/[feature-name]` | `feature/user-login` |
| `PROJ-123 用户登录` | `feat/[ISSUE_ID]-[feature-name]` | `feat/PROJ-123-user-login` |

## 记忆文件

首次运行 `/codespec:workflow` 或 `/codespec:constitution` 时自动生成：

| 文件 | 说明 |
|------|------|
| `.codespec/memory/constitution.md` | 项目章程：编码规范、架构约束、目录结构、命名规则、Git 工作流 |
| `.codespec/memory/project-context.json` | 项目上下文：技术栈、框架版本、依赖、构建工具 |
| `.codespec/memory/user-preferences.json` | 用户偏好：设计方案倾向（自动积累） |
| `.codespec/memory/code-patterns.json` | 代码模式：高质量实现模式（自动积累） |
| `.codespec/memory/workflow-history.json` | 工作流历史：执行记录（自动积累） |

前两个要求存在才能启动工作流，后三个自动积累、缺失不阻塞。

## 默认值

不创建 `workflow.json` 时的完整默认配置：

```json
{
  "version": "1.0",
  "core": {
    "specsDir": ".codespec/specs",
    "language": "zh-CN"
  },
  "project": {
    "branchPattern": "feature/[feature-name]",
    "issueIdPattern": "[A-Z]+-[0-9]+"
  },
  "extensions": { "stages": [] }
}
```
