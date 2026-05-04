# CodeSpec

中文 | [English](./README.EN.md)

> 一个规格驱动开发（SDD）、技术栈无关、支持断点续做、可扩展、半自动，覆盖需求规格到代码交付的 AI 全流程编排插件

<img src="./docs/CodeSpec.svg" width="100%" />

## 特性

- **核心管线固定**：规格生成 → 需求澄清 → 方案设计 → 任务拆解 → 代码实现 → 代码审查（6 个核心阶段，不可跳过）
- **Hook Points 扩展**：通过 `runBefore`/`runAfter` 在任意核心阶段前/后插入自定义扩展（如需求获取、E2E 测试、部署等）
- **技术栈无关**：核心命令不硬编码任何技术栈信息；所有项目知识从配置和记忆文件中获取
- **平台无关**：不绑定任何特定的需求管理、文档或设计工具；通过前置扩展对接任意外部系统
- **中断可恢复**：每个阶段完成后自动持久化状态，支持断点续做
- **记忆系统**：自动积累项目知识（工作流历史、用户偏好、代码模式），越用越智能

## 设计哲学

| 原则 | 具体体现 |
|---|---|
| **Spec 是校验协议，不是永久真理** | AI 写 spec 给人审，确认理解一致后推进；不追求 spec 作为系统的 source of truth |
| **AI 写、人审、人不维护** | 所有文档产物由 AI 生成和读取，人只在暂停点审查决策，不手动编辑产物 |
| **半自动执行** | 一条命令启动，AI 自动推进，关键决策点（需求澄清、方案选择、任务确认）暂停等人 |
| **一次性工作流** | 每个 feature 分支一个独立生命周期，完成后清理阶段产物；新需求新工作流，不搞累积式 spec |

## 文档

| 文档 | 说明 |
|------|------|
| [快速开始](docs/zh/getting-started.md) | 安装、环境要求、第一次运行 |
| [配置参考](docs/zh/configuration.md) | workflow.json 完整配置说明 |
| [Hook Points 扩展](docs/zh/hook-points.md) | 在核心阶段前/后插入自定义扩展 |
| [对比与设计哲学](docs/zh/comparison-and-philosophy.md) | 了解 CodeSpec 与其他工具的区别，以及它的设计哲学 |

## 快速开始

```bash
# 添加插件市场
/plugin marketplace add codespec-marketplace LucivHuang/CodeSpec

# 安装插件：
/plugin install codespec@codespec-marketplace

# 运行（首次会自动引导项目初始化）
/codespec:workflow 新增用户个人资料页面功能
```

环境要求：`bash` + `jq`；`git` 可选但推荐。

详见 [快速开始指南](docs/zh/getting-started.md)。

## 命令一览

| 命令 | 用途 |
|------|------|
| `/codespec:workflow` | 完整工作流（一键走完全流程） |
| `/codespec:specify` | 生成功能规格 |
| `/codespec:clarify` | 需求澄清 |
| `/codespec:plan` | 方案设计 |
| `/codespec:tasks` | 任务拆解 |
| `/codespec:implement` | 执行实现 |
| `/codespec:review` | 代码审查 |
| `/codespec:refine` | 完成后微调 |
| `/codespec:constitution` | 项目规范初始化/更新 |

## 产物说明

```
.codespec/
├── config/workflow.json       # 用户创建 — 工作流配置（可选）
├── memory/                    # 首次初始化 — 项目记忆文件
└── specs/<feature-name>/
    ├── spec.md                # 阶段 1-2 — 功能规格说明
    ├── plan.md                # 阶段 3 — 方案设计
    ├── tasks.md               # 阶段 4 — 任务清单
    ├── review-report.md       # 阶段 6 — 代码审查报告
    └── extensions/            # 可选 — 扩展阶段产出
```

## License

MIT
