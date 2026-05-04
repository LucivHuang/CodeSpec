---
description: Execute implementation plan by processing and executing all tasks defined in tasks.md
handoffs:
  - label: Review code
    agent: codespec:review
    prompt: Review implemented code
    send: true
---

## User Input

```text
$ARGUMENTS
```

You **must** consider the user input (if non-empty) before proceeding.

> General rules (output language, specification references, etc.) see [`../shared/shared-instructions.md`](../shared/shared-instructions.md)

Output contract see [`../shared/command-contracts.md`](../shared/command-contracts.md).

## Plugin Root Resolution

Before calling any `scripts/bash/*`, ensure `CLAUDE_PLUGIN_ROOT` is valid:

```bash
# If CLAUDE_PLUGIN_ROOT is not set or invalid, attempt to resolve
if [[ -z "${CLAUDE_PLUGIN_ROOT:-}" || ! -d "$CLAUDE_PLUGIN_ROOT/scripts/bash" ]]; then
  source "$(dirname "$(dirname "${BASH_SOURCE[0]}")")/scripts/bash/common.sh"
  resolve_plugin_root || exit 1
fi
```

## Execution Flow

**Input**: tasks.md path (containing task list and requirement coverage matrix)

**Precondition**: tasks-done gate check passes

**Execution Steps**:

1. **Initialization**
   - Call `check-prerequisites.sh --json --require-tasks --include-tasks`
   - Parse FEATURE_DIR, AVAILABLE_DOCS, TASKS_CONTENT
   - Gate check: `gate-check.sh tasks-done`

2. **Delegate to code-implementer agent for implementation**
   - Pass in: FEATURE_DIR, AVAILABLE_DOCS, TASKS_CONTENT, REQUIREMENTS_BASELINE, REQUIREMENT_TRACEABILITY
   - Agent responsibilities:
     - Execute tasks one by one in phase and dependency order
     - Mark `[x]` in tasks.md after completing tasks
     - Handle errors and blocked tasks
     - Verify requirement coverage (every `RQ-*` has implementation evidence)
   - Agent reads plan.md, constitution.md, code-exploration.md and other documents on demand

3. **Verify Artifacts**
   - Count completion status from tasks.md:
     ```bash
     TOTAL=$(grep -c '^\- \[.\] T[0-9]' "$FEATURE_DIR/tasks.md")
     COMPLETED=$(grep -c '^\- \[x\] T[0-9]' "$FEATURE_DIR/tasks.md")
     ```
   - Parse JSON returned by agent:
     - Blocked tasks and reasons
     - Summary of changed files
     - List of uncovered requirements (should be empty)

**Artifacts**:
- Code changes (implemented per tasks.md)
- tasks.md (updated markers to `[x]`)

**User Interaction**:
- None (automatic execution, unless tool call failures encountered)

**Next Steps**: `/codespec:review`

**Domain Knowledge**: Implementation execution rules see [`../agents/code-implementer.md`](../agents/code-implementer.md)
