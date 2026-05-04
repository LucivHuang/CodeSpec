# CodeSpec

[中文](./README.zh-CN.md) | English

> A Spec-Driven Development (SDD), tech-stack-agnostic, resumable, extensible, semi-automated AI workflow orchestration plugin covering the full journey from requirement specifications to code delivery.

<img src="./docs/CodeSpec.svg" width="100%" />

## Features

- **Fixed Core Pipeline**: Spec Generation → Requirement Clarification → Solution Design → Task Breakdown → Code Implementation → Code Review (6 core stages, non-skippable)
- **Hook Points Extension**: Insert custom extensions before/after any core stage via `runBefore`/`runAfter` (e.g., requirement fetching, E2E testing, deployment)
- **Tech-Stack Agnostic**: Core commands don't hardcode any tech stack information; all project knowledge comes from configuration and memory files
- **Platform Agnostic**: Not bound to any specific requirement management, documentation, or design tools; integrate with any external system through pre-extensions
- **Resumable from Interruption**: Auto-persists state after each stage completion, supports resume from checkpoint
- **Memory System**: Auto-accumulates project knowledge (workflow history, user preferences, code patterns), gets smarter with use

## Design Philosophy

| Principle | Manifestation |
|-----------|---------------|
| **Spec is a verification protocol, not permanent truth** | AI writes spec for human review, confirms understanding alignment before proceeding; doesn't pursue spec as system's source of truth |
| **AI writes, human reviews, human doesn't maintain** | All document artifacts generated and read by AI, humans only review decisions at pause points, don't manually edit artifacts |
| **Semi-automatic execution** | One command to start, AI auto-advances, pauses at key decision points (requirement clarification, solution selection, task confirmation) for human input |
| **One-time workflow** | Each feature branch has an independent lifecycle, cleans up stage artifacts after completion; new requirements get new workflows, no cumulative specs |

## Documentation

| Document | Description |
|----------|-------------|
| [Getting Started](docs/en/getting-started.md) | Installation, prerequisites, first run |
| [Configuration Reference](docs/en/configuration.md) | Complete workflow.json configuration guide |
| [Hook Points Extension](docs/en/hook-points.md) | Insert custom extensions before/after core stages |
| [Comparison and Design Philosophy](docs/en/comparison-and-philosophy.md) | Understand CodeSpec's differences from other tools and its design philosophy |

## Quick Start

```bash
# Installation
claude plugin install <path-or-url-to-codespec>

# Run (first time will auto-guide project initialization)
/codespec:workflow Add user profile page feature
```

Prerequisites: `bash` + `jq`; `git` optional but recommended.

See [Getting Started Guide](docs/en/getting-started.md) for details.

## Command Overview

| Command | Purpose |
|---------|---------|
| `/codespec:workflow` | Complete workflow (one-click full process) |
| `/codespec:specify` | Generate feature specification |
| `/codespec:clarify` | Requirement clarification |
| `/codespec:plan` | Solution design |
| `/codespec:tasks` | Task breakdown |
| `/codespec:implement` | Execute implementation |
| `/codespec:review` | Code review |
| `/codespec:refine` | Post-completion fine-tuning |
| `/codespec:constitution` | Project convention initialization/update |

## Artifact Structure

```
.codespec/
├── config/workflow.json       # User-created — workflow configuration (optional)
├── memory/                    # First-time init — project memory files
└── specs/<feature-name>/
    ├── spec.md                # Stage 1-2 — feature specification
    ├── plan.md                # Stage 3 — solution design
    ├── tasks.md               # Stage 4 — task list
    ├── review-report.md       # Stage 6 — code review report
    └── extensions/            # Optional — extension stage outputs
```

## License

MIT
