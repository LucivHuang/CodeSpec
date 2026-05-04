---
description: Conduct a comprehensive technology-agnostic review of implementation code, outputting a graded issue list and scoring report
handoffs:
  - label: Fix review issues
    agent: codespec:implement
    prompt: Fix issues found in code review
  - label: Refine code
    agent: codespec:refine
    prompt: Refine code based on review results
---

## User Input

```text
$ARGUMENTS
```

You **must** consider the user input (if non-empty) before proceeding.

> General rules (output language, specification references, etc.) see [`../shared/shared-instructions.md`](../shared/shared-instructions.md)

Output contract see [`../shared/command-contracts.md`](../shared/command-contracts.md).

## Plugin Root Resolution

Before calling any `scripts/bash/*` or reading templates, ensure `CLAUDE_PLUGIN_ROOT` is valid:

```bash
# If CLAUDE_PLUGIN_ROOT is not set or invalid, attempt to resolve
if [[ -z "${CLAUDE_PLUGIN_ROOT:-}" || ! -d "$CLAUDE_PLUGIN_ROOT/scripts/bash" ]]; then
  source "$(dirname "$(dirname "${BASH_SOURCE[0]}")")/scripts/bash/common.sh"
  resolve_plugin_root || exit 1
fi
```

## Execution Flow

**Input**: FEATURE_DIR path (containing implementation code)

**Precondition**: implement-done gate check passes

**Execution Steps**:

1. **Initialization**
   - Call `check-prerequisites.sh --json --require-tasks --include-tasks`
   - Parse FEATURE_DIR and AVAILABLE_DOCS
   - Gate check: `gate-check.sh implement-done`

2. **Collect Change Data**
   - Detect baseline branch (main/master/develop)
   - Extract changed file list: `git diff --name-only BASE_BRANCH...HEAD`
   - Collect diff content and change statistics

3. **Prepare Review Context**
   - CHANGED_FILES: list of changed files
   - DIFF_CONTENT: diff content (for many files, only pass statistics, agent reads on demand)
   - REQUIREMENTS_BASELINE: `RQ-*` checklist from spec.md
   - REQUIREMENT_TRACEABILITY: requirement coverage matrix from tasks.md
   - REVIEW_TEMPLATE: review report template
   - Agent reads constitution.md, code-patterns.json, plan.md on demand

4. **Delegate to code-reviewer agent for review**
   - Change scale strategy:
     - ≤15 files → 1 agent
     - 16-30 files → 2 agents in parallel (split by module)
     - >30 files → 2 agents in parallel + notify user of large change scope
   - Agent responsibilities:
     - Score across 7 dimensions (compliance, quality, security, maintainability, impact, requirements, architecture)
     - Identify P0/P1/P2 issues
     - Verify requirement coverage
     - Write review-report.md

5. **Verify Artifacts**
   - Check review-report.md exists and is non-empty
   - If missing, retry once, if still fails then ask user

6. **User Interaction: P0 Issue Handling** (conditionally triggered, per shared-instructions.md)
   - P0 = 0 → Report pass, continue workflow
   - P0 > 0 → Pause, display P0 issue list, let user choose:
     - Fix and re-review
     - Waive and continue (mark `[User Waived]`)
     - Terminate workflow

**Artifacts**:
- `review-report.md` - Code review report (including scores, issue list, requirement coverage verification)

**User Interaction**:
- P0 issue handling: pause when critical issues found (see shared-instructions.md)

**Next Steps**:
- Has P0 issues → `/codespec:refine` to fix
- No P0 issues → workflow complete

**Key Rules**:
- Review criteria dynamically obtained from memory files (technology-agnostic)
- Do not modify code (read-only review)
- P0 must pause for user decision
- High-value patterns can be deposited into code-patterns.json
