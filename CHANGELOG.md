# Changelog

## [1.0.0] - 2026-05-04

### Features

- **Core Pipeline**: 6-stage fixed workflow - Spec generation → Requirements clarification → Solution design → Task breakdown → Code implementation → Code review
- **Hook Points Extension**: Insert custom extensions before/after any core stage via `runBefore`/`runAfter` (e.g., requirement fetching, E2E testing, deployment)
- **Technology-Agnostic**: Core commands don't hardcode any tech stack; all project knowledge from configuration and memory files
- **Platform-Agnostic**: Not tied to any specific requirement management, documentation, or design tools; integrate with external systems via extensions
- **Resumable Workflow**: Automatically persists state after each stage, supports resuming from interruption
- **Memory System**: Automatically accumulates project knowledge (workflow history, user preferences, code patterns)
- **Requirement Coverage Guard**: `RQ-*` anchors tracked throughout from specification to implementation
- **Semi-Automated Execution**: One command to start, AI auto-advances, pauses at key decision points for human input
- **Specification-Driven Development**: AI writes spec for human review, confirms understanding before proceeding
