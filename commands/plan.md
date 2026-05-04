---
description: Execute implementation planning workflow using plan template, generate design artifacts.
handoffs:
  - label: Create tasks
    agent: codespec:tasks
    prompt: Break down plan into tasks
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

Before calling any `scripts/bash/*` or `templates/*`, ensure `CLAUDE_PLUGIN_ROOT` is valid:

```bash
# If CLAUDE_PLUGIN_ROOT is not set or invalid, try to resolve
if [[ -z "${CLAUDE_PLUGIN_ROOT:-}" || ! -d "$CLAUDE_PLUGIN_ROOT/scripts/bash" ]]; then
  source "$(dirname "$(dirname "${BASH_SOURCE[0]}")")/scripts/bash/common.sh"
  resolve_plugin_root || exit 1
fi
```

## Execution Flow

**Input**: spec.md path (contains requirement anchors)

**Prerequisites**: clarify-done gate passed

**Execution Steps**:

1. **Initialize**
   - Call `check-prerequisites.sh --json --setup-plan`
   - Parse FEATURE_SPEC, IMPL_PLAN, FEATURE_DIR, BRANCH
   - Gate check: `gate-check.sh clarify-done`

2. **Load context**
   - Read spec.md (feature specification)
   - Read constitution.md (coding standards)
   - Read IMPL_PLAN template

3. **Plan Step 1: Technical research**
   - Extract NEEDS CLARIFICATION from technical context
   - Dispatch research agent to resolve technical questions
   - Generate research.md (decisions + rationale + alternatives)

4. **Plan Step 2: Code exploration**
   - Launch code-explorer agent (1-2, based on requirement complexity)
   - Agent 1: Implementation patterns (business code, code flow, domain patterns)
   - Agent 2: Reuse assessment (common libraries, utility functions, base components)
   - Generate code-exploration.md (key files + reusable code)

5. **Plan Step 3: Technical clarification** (conditional execution)
   - Condition: multiple implementation approaches or unclear boundaries
   - Extract items needing confirmation from code-exploration.md
   - User interaction: choose implementation approach (see shared-instructions.md)
   - Record choice to user-preferences.json

6. **Plan Step 4: Architecture design**
   - 4.1 Assess solution complexity
     - Single path → launch 1 code-architect (pragmatic)
     - 2 candidates → launch 2 code-architects (different design philosophies)
     - ≥3 variations → launch 3 code-architects (minimal/clean/pragmatic)
   - 4.2 Solution comparison and user selection
     - Generate comparison summary (change scope, file count, reuse rate, complexity, risk)
     - User interaction: select solution (see shared-instructions.md)
     - Record selection to user-preferences.json
   - 4.3 Refine selected solution
     - Generate data-model.md (data model)
     - Generate contracts/ (API contracts)
     - Generate quickstart.md (quick start guide)
     - Update plan.md (architecture decisions, build sequence, file list)

**Artifacts**:
- `research.md` - Technical research report
- `code-exploration.md` - Code exploration report
- `data-model.md` - Data model design
- `contracts/` - API contract files
- `quickstart.md` - Quick start guide
- `plan.md` - Implementation plan (updated)

**User Interaction**:
- Plan Step 3: Technical selection clarification (conditionally triggered)
- Plan Step 4.2: Solution selection (see shared-instructions.md)

**Next Steps**: `/codespec:tasks`

**Key Rules**:
- Plan Step 2 mandatory (must explore code before design)
- Plan Step 3 conditionally mandatory (when multiple solutions or unclear boundaries)
- All implementation suggestions must reference code-exploration.md
