---
description: Generate executable, dependency-ordered tasks.md file based on available design artifacts
handoffs:
  - label: Implement project
    agent: codespec:implement
    prompt: Start implementation in phases
    send: true
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider user input (if not empty) before proceeding.

> General rules (output language, specification references, etc.) see [`../shared/shared-instructions.md`](../shared/shared-instructions.md)

Output contract see [`../shared/command-contracts.md`](../shared/command-contracts.md).

## Plugin Root Resolution

Before calling any `scripts/bash/*` or reading templates, ensure `CLAUDE_PLUGIN_ROOT` is valid:

```bash
# If CLAUDE_PLUGIN_ROOT is not set or invalid, try to resolve
if [[ -z "${CLAUDE_PLUGIN_ROOT:-}" || ! -d "$CLAUDE_PLUGIN_ROOT/scripts/bash" ]]; then
  source "$(dirname "$(dirname "${BASH_SOURCE[0]}")")/scripts/bash/common.sh"
  resolve_plugin_root || exit 1
fi
```

## Execution Flow

**Input**: plan.md path (contains architecture design)

**Prerequisites**: plan-done gate passed

**Execution Steps**:

1. **Initialize**
   - Call `check-prerequisites.sh --json`
   - Parse FEATURE_DIR and AVAILABLE_DOCS

2. **Load design documents** (read as needed)
   - **Required**: plan.md (tech stack, architecture, file structure)
   - **Required**: requirement anchors from spec.md (`RQ-*` checklist)
   - **Required**: code-exploration.md (reusable code, implementation patterns)
   - **Optional**: data-model.md, contracts/, research.md, quickstart.md

3. **Delegate to task-planner agent to generate tasks**
   - Pass in: FEATURE_DIR, AVAILABLE_DOCS, tasksTemplate, tasksFormatRules, requirementAnchors, OUTPUT_LANGUAGE
   - Agent responsible for:
     - Organize tasks by user story
     - Generate dependency graph
     - Mark parallelizable tasks [P]
     - Generate requirement coverage matrix (`RQ-* -> TaskID[]`)
     - Write to tasks.md

4. **Validate artifacts**
   - Format validation: all tasks follow `- [ ] [ID] [P?] [Story?] description` format
   - Requirement coverage check: each `RQ-*` maps to at least 1 task ID
   - When unmapped requirements found, must add tasks

5. **User interaction: task confirmation** (per "User Interaction Strategy" in shared-instructions.md)
   - Show task summary: total tasks, phase breakdown, parallelizable task count, MVP scope
   - Wait for user approval before continuing (final confirmation before code implementation)

**Artifacts**:
- `tasks.md` - Task list (includes requirement coverage matrix)

**User Interaction**:
- Task confirmation: pause after generation, wait for user approval (see shared-instructions.md)

**Next Steps**: `/codespec:implement`

**Domain Knowledge**: Task generation rules see [`../agents/task-planner.md`](../agents/task-planner.md), format specification see [`../shared/tasks-format.md`](../shared/tasks-format.md)
