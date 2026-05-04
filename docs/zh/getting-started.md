# 快速开始

## 安装

```bash
claude plugin install https://github.com/LucivHuang/CodeSpec.git
```

## 环境要求

- 必需：`bash`、`jq`（macOS 用 `brew install jq`）
- 可选：`git`（缺失时可降级运行，但分支相关能力会受限）

## 第一次运行

直接运行 `/codespec:workflow` 即可。工作流会自动检测是否缺少记忆文件，如果缺少会引导你完成项目初始化：

1. 询问你是否有特殊规范（编码规范、分支规范、Commit 规范等），可直接描述或提供文档 URL / 本地文件路径
2. 自动扫描项目结构（package.json、tsconfig、.eslintrc 等），补充未提及的技术栈信息
3. 合并生成 `.codespec/memory/constitution.md` 和 `project-context.json`
4. 退出工作流，提示你检查生成的规范文档
5. 确认无误后，重新运行 `/codespec:workflow` 正式开始

也可单独运行 `/codespec:constitution` 提前完成初始化。

## 基本用法

```bash
# 完整工作流（一键执行 6 个核心阶段）
/codespec:workflow 新增用户个人资料页面功能

# 分步执行
/codespec:specify 新增用户个人资料页面功能
/codespec:clarify
/codespec:plan
/codespec:tasks
/codespec:implement
/codespec:review

# 工作流完成后微调
/codespec:refine 把登录超时从30s改为60s
```

## 工作流 6 个核心阶段

```
阶段 1: 规格生成    → 从需求描述生成结构化的功能规格说明（spec.md）
阶段 2: 需求澄清    → 识别模糊点，交互式澄清，生成需求锚点（RQ-*）
阶段 3: 方案设计    → 探索代码库，生成多个设计方案，用户选择
阶段 4: 任务拆解    → 将方案分解为可执行的任务清单（tasks.md）
阶段 5: 代码实现    → 逐任务执行代码变更，实时标记完成进度
阶段 6: 代码审查    → 7 维度审查，P0/P1/P2 分级，生成审查报告
```

每个阶段之间有强制暂停点（需求澄清、方案选择、任务确认），确保人始终在回路中。

## 需求输入方式

工作流通过 `$ARGUMENTS` 接收需求，支持多种输入方式：

```bash
# 直接描述需求
/codespec:workflow 新增用户个人资料页面，支持头像上传和昵称修改

# 指向本地需求文档（AI 会用 Read 工具读取）
/codespec:workflow 需求见 ./docs/prd/user-profile.md

# 提供在线链接（需要页面可匿名访问，否则 AI 只能拿到登录页）
/codespec:workflow https://example.com/public-doc
```

**关于在线文档平台**（飞书、语雀、腾讯文档等）：这类平台通常需要登录且内容由 JS 动态渲染，AI 的 WebFetch 工具无法直接获取内容。推荐的做法：

**通过 Hook Points 扩展**对接平台 API（配置 `runBefore: 1` 的前置扩展，通过 `requirementContent` 传入内容，详见 [Hook Points 扩展](hook-points.md)）

## 下一步

- [配置参考](./configuration.md) — 自定义工作流行为
- [Hook Points 扩展](./hook-points.md) — 对接外部系统（Jira、Figma、CI/CD 等）
- [对比与设计哲学](./comparison-and-philosophy.md) — 理解 CodeSpec 的设计哲学
