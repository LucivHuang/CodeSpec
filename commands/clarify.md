---
description: Identify ambiguous areas in feature specification, ask up to 5 clarification questions, encode answers back into specification.
handoffs:
  - label: Build technical plan
    agent: codespec:plan
    prompt: Create plan for the specification. I'm using...
---

## User Input

```text
$ARGUMENTS
```

> General rules see [`../shared/shared-instructions.md`](../shared/shared-instructions.md)

## Plugin Root Resolution

Before calling any `scripts/bash/*`, ensure `CLAUDE_PLUGIN_ROOT` is valid:

```bash
# If CLAUDE_PLUGIN_ROOT is not set or invalid, try to resolve
if [[ -z "${CLAUDE_PLUGIN_ROOT:-}" || ! -d "$CLAUDE_PLUGIN_ROOT/scripts/bash" ]]; then
  source "$(dirname "$(dirname "${BASH_SOURCE[0]}")")/scripts/bash/common.sh"
  resolve_plugin_root || exit 1
fi
```

## Execution Flow

**Input**: spec.md path (usually obtained from check-prerequisites.sh)

**Prerequisites**: spec.md exists

**Execution Steps**:

1. **Locate specification file**
   - Call `check-prerequisites.sh --json --paths-only`
   - Parse FEATURE_DIR and FEATURE_SPEC

2. **Delegate to clarification-analyst agent to scan ambiguities**
   - Pass in: FEATURE_SPEC path, OUTPUT_LANGUAGE
   - Agent responsible for: identifying ambiguous areas, generating ≤5 prioritized questions (with recommended answers)
   - Parse returned questions list and coverage_summary
   - No questions → report "no critical ambiguities" and skip subsequent steps

3. **User interaction: clarify questions one by one** (per "User Interaction Strategy" in shared-instructions.md)
   - Present 1 question at a time, with recommended answer and rationale
   - Provide options for quick user response
   - Stop conditions: all questions resolved / user says "done" / reached 5 questions

4. **Incrementally integrate answers into spec.md**
   - Append Q&A in `## Clarifications` > `### Session YYYY-MM-DD`
   - Apply clarifications to corresponding sections (guided by affected_sections)
   - Save file after each integration

5. **Generate requirement anchors** (prevent omissions, must execute)
   - Extract "non-omissible requirements checklist" from spec.md
   - Write to `## Requirements Baseline` section
   - Assign stable ID to each requirement (e.g., `RQ-001`)
   - Cover functional requirements, boundary conditions, key constraints, success criteria
   - Recommend 8-25 items, avoid too coarse or too fine

6. **Validate artifacts**
   - Updated sections have no residual placeholders, no contradictions
   - Valid Markdown format, consistent terminology

**Artifacts**:
- `spec.md` (updated) - contains clarification records and requirement anchors

**User Interaction**:
- Pause to ask when ambiguities found (see shared-instructions.md)
- When user requests skip: warn of rework risk → record `[User skipped clarification]` → continue after confirmation

**Next Steps**: `/codespec:plan`

**Domain Knowledge**: Ambiguity taxonomy see [`../agents/clarification-analyst.md`](../agents/clarification-analyst.md)
