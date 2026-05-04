# Getting Started

## Installation

```bash
claude plugin install https://github.com/LucivHuang/CodeSpec.git
```

## Prerequisites

- Required: `bash`, `jq` (macOS: `brew install jq`)
- Optional: `git` (can run in degraded mode without it, but branch-related features will be limited)

## First Run

Simply run `/codespec:workflow`. The workflow will automatically detect missing memory files and guide you through project initialization:

1. Ask if you have special conventions (coding standards, branch conventions, commit conventions, etc.). You can describe directly or provide documentation URL / local file path
2. Automatically scan project structure (package.json, tsconfig, .eslintrc, etc.) to supplement unmentioned tech stack information
3. Merge and generate `.codespec/memory/constitution.md` and `project-context.json`
4. Exit workflow, prompting you to review the generated specification documents
5. After confirmation, re-run `/codespec:workflow` to officially start

You can also run `/codespec:constitution` separately to complete initialization in advance.

## Basic Usage

```bash
# Complete workflow (one-click execution of 6 core stages)
/codespec:workflow Add user profile page feature

# Step-by-step execution
/codespec:specify Add user profile page feature
/codespec:clarify
/codespec:plan
/codespec:tasks
/codespec:implement
/codespec:review

# Fine-tuning after workflow completion
/codespec:refine Change login timeout from 30s to 60s
```

## 6 Core Workflow Stages

```
Stage 1: Spec Generation    → Generate structured feature specification from requirement description (spec.md)
Stage 2: Requirement Clarification → Identify ambiguities, interactive clarification, generate requirement anchors (RQ-*)
Stage 3: Solution Design    → Explore codebase, generate multiple design options, user selects
Stage 4: Task Breakdown     → Decompose solution into executable task list (tasks.md)
Stage 5: Code Implementation → Execute code changes task-by-task, mark completion progress in real-time
Stage 6: Code Review        → 7-dimension review, P0/P1/P2 grading, generate review report
```

There are mandatory pause points between each stage (requirement clarification, solution selection, task confirmation) to ensure humans remain in the loop.

## Requirement Input Methods

The workflow receives requirements through `$ARGUMENTS`, supporting multiple input methods:

```bash
# Direct requirement description
/codespec:workflow Add user profile page with avatar upload and nickname modification

# Point to local requirement document (AI will read using Read tool)
/codespec:workflow See requirements in ./docs/prd/user-profile.md

# Provide online link (page must be anonymously accessible, otherwise AI only gets login page)
/codespec:workflow https://example.com/public-doc
```

**About online document platforms** (Feishu, Yuque, Tencent Docs, etc.): These platforms typically require login and content is dynamically rendered by JS, so AI's WebFetch tool cannot directly retrieve content. Recommended approach:

**Extend through Hook Points** to integrate with platform APIs (configure `runBefore: 1` pre-extension, pass content through `requirementContent`, see [Hook Points Extension](hook-points.md) for details)

## Next Steps

- [Configuration Reference](./configuration.md) — Customize workflow behavior
- [Hook Points Extension](./hook-points.md) — Integrate external systems (Jira, Figma, CI/CD, etc.)
- [Comparison and Design Philosophy](./comparison-and-philosophy.md) — Understand CodeSpec's design philosophy
