---
description: Execute the complete intelligent development workflow from requirements gathering to delivery (tech-stack agnostic · extensible via Hook Points)
automation_level: full
file_permissions:
  create: auto
  read: auto
  update: auto
  delete: confirm
handoffs:
  - label: Continue specification
    agent: codespec:specify
    prompt: Continue writing feature specification
  - label: Continue solution design
    agent: codespec:plan
    prompt: Continue solution design
---

# CodeSpec Workflow

## Deliverable Contract

**Your only formal deliverable is the [Final Completion Report] defined at the end of this file.** Do not output stage summaries between stages; brief progress updates are acceptable. Your task is only complete when the full final report has been output.

**⚠️ Workflow Completion Conditions (all required):**
1. Core stages 1-6 all executed
2. All configured extension stages (Hook Points) executed
3. Memory recording and state cleanup at pipeline end executed
4. Final completion report output

**Completing only core stages without executing extension pipeline and final report = workflow incomplete.**

**⚠️ Mandatory Pause Points (must stop and wait for user response before continuing):**

1. **Requirements Clarification** (Stage 2): When clarify agent finds ambiguities, must use AskUserQuestion to query user, **wait for user response** before continuing
2. **Solution Confirmation** (Stage 3): After solution design completes, must use AskUserQuestion to let user choose solution, **wait for user response** before continuing
3. **Task Confirmation** (Stage 4): After tasks.md generation and before implementation starts, must use AskUserQuestion to let user review task list and confirm implementation start, **wait for explicit user approval** before executing code changes
4. **Review P0 Issues** (Stage 6): When code review finds P0 issues, must use AskUserQuestion to show issue list and let user choose disposition, **wait for user response** before continuing
5. **Unrecoverable Errors**: When tool invocation fails and retry is ineffective, must stop and ask user

**These pause points cannot be skipped, cannot auto-select default values, cannot be replaced with other forms.**

## User Input

```text
$ARGUMENTS
```

If the user provided input, carefully consider this input before continuing.

## Specifications and Language

- **Shared Instructions**: [`shared-instructions.md`](../shared/shared-instructions.md) (includes execution gate rules)
- **Configuration Specification**: [`config-schema.md`](../shared/config-schema.md)
- **Output Contract**: [`command-contracts.md`](../shared/command-contracts.md)
- **Constitution Center**: `.codespec/memory/constitution.md` (if exists)

## Plugin Root Resolution

Before first invocation of any `scripts/bash/*`, obtain and set `CLAUDE_PLUGIN_ROOT` via workflow-init.sh:

```bash
# workflow-init.sh will output PLUGIN_ROOT=<path>
INIT_OUTPUT=$(bash "$CLAUDE_PLUGIN_ROOT/scripts/bash/workflow-init.sh" 2>&1)
if [[ $? -ne 0 ]]; then
  echo "ERROR: Workflow initialization failed" >&2
  echo "$INIT_OUTPUT" >&2
  exit 1
fi

# Extract PLUGIN_ROOT from initialization output and set environment variable
export CLAUDE_PLUGIN_ROOT=$(echo "$INIT_OUTPUT" | grep '^PLUGIN_ROOT=' | cut -d'=' -f2-)

if [[ -z "${CLAUDE_PLUGIN_ROOT:-}" || ! -d "$CLAUDE_PLUGIN_ROOT/scripts/bash" ]]; then
  echo "ERROR: CLAUDE_PLUGIN_ROOT is not set or points to an invalid plugin root" >&2
  exit 1
fi
```

## Execution Flow

```
Initialization → [Pre-extensions] → Stage1 → [Extensions] → Stage2 → [Extensions] → Stage3 → [Extensions] → Stage4 → [Extensions] → Stage5 → [Extensions] → Stage6 → [Post-extensions] → Final Report
```

- Core stages 1-6: Fixed, tech-stack agnostic, cannot be skipped
- Extension pipeline: Defined by `workflow.json`'s `extensions.stages`, declares execution before/after which core stage via `runBefore`/`runAfter`

### Agent Orchestration Pattern

You must use the **Orchestrator → Sub-agents** pattern to execute this workflow:

| Layer                                                                                                      | Role       | Description                                            |
| --------------------------------------------------------------------------------------------------------- | ---------- | ----------------------------------------------- |
| **workflow.md**                                                                                           | Orchestrator     | Manages full flow, user interaction, state persistence                |
| **Sub-commands** (specify/plan/tasks/implement/review)                                                           | Stage Orchestrator | Manages intra-stage flow, delegates domain work to expert agents     |
| **Expert agents** (requirements-analyst / code-explorer / code-architect / task-planner / code-implementer / code-reviewer) | Stateless Expert | Launched by Task tool, focuses on single domain, returns structured results |

**Delegation Method**: You must use the Task tool to launch sub-commands or agents. Agents execute in isolated context and return results to you.

---

## Initialization

Complete initialization in a single terminal invocation (environment check + config parsing + state detection + memory file validation).

**Note**: Initialization script already executed in "Plugin Root Resolution" step, parse its output here:

```bash
# Parse configuration variables from initialization output
eval "$(echo "$INIT_OUTPUT" | grep -E '^(CONFIG_|MISSING_|RESUME_|STATUS_|OUTPUTS_|ENABLED_|PROJECT_)')"
```

**Handle Initialization Results:**

- **`ENV_CHECK_FAILED=true`** → Display errors and terminate.
- **Interruption detected** (`RESUME_DETECTED=true`, including: `interrupted=true`, existence of `in_progress` stage, or some stages `completed` while others `pending`) → AskUserQuestion whether to resume. If resume, skip completed stages; if not resume, `workflow_state_cleanup` then start from beginning. Detection strictly matches state file by current branch, no cross-branch rollback.
- **No interruption** → Only check memory files and continue. State file created after Stage 1 generates `BRANCH/FEATURE_DIR`, avoiding writes to old branch directory.

### Memory File Check (Required)

Read `MISSING_MEMORY_FILES` from initialization output:

- **Has missing files** → Execute project initialization per [`constitution.md`](./constitution.md) (query specifications → scan project → generate memory files → prompt user to check then re-run), **terminate current workflow**
- **All exist** → Read memory files (do not create state file yet):

```bash
source "$CLAUDE_PLUGIN_ROOT/scripts/bash/workflow-state.sh"
OUTPUT_LANGUAGE="${CONFIG_LANGUAGE:-zh-CN}"
SPECS_DIR="${CONFIG_SPECS_DIR:-.codespec/specs}"
PROJECT_ISSUE_PATTERN="${PROJECT_ISSUE_PATTERN:-}"
if [[ -n "$PROJECT_ISSUE_PATTERN" ]]; then
  ISSUE_ID=$(echo "$ARGUMENTS" | grep -oE "$PROJECT_ISSUE_PATTERN" | head -1)
fi
```

### Parse Extension Hook Points

Group from `ENABLED_EXTENSIONS` by hook point for subsequent stage scheduling:

```
EXTENSIONS_BEFORE_1 = [extensions with runBefore=1]
EXTENSIONS_AFTER_1  = [extensions with runAfter=1]
EXTENSIONS_BEFORE_2 = [extensions with runBefore=2]
...
EXTENSIONS_AFTER_6  = [extensions with runAfter=6]
EXTENSIONS_LEGACY   = [extensions without runBefore or runAfter] → merge into EXTENSIONS_AFTER_6
```

During parsing, validate `runBefore`/`runAfter` are integers 1-6, issue warning and skip extension if invalid.

---

## Core Stage Execution (with Hook Points)

For each core stage N (N = 1 to 6), execute in the following order:

### 1. Execute `EXTENSIONS_BEFORE_N`

If extensions with `runBefore: N` exist, execute sequentially in array order (following the 6-step flow in "Extension Execution General Rules" below, including state persistence).

**Special handling: extensions with `runBefore: 1`** (pre-requirements gathering):

Since Stage 1 creates `FEATURE_DIR`, pre-extensions cannot write artifacts to `FEATURE_DIR/extensions/`. Therefore:
- Pre-extensions return results via JSON contract, orchestrator parses the `requirementContent` field
- If extension returns `requirementContent`, use it as requirements input for Stage 1 (replacing text portion in `$ARGUMENTS`)
- Issue ID pattern in `$ARGUMENTS` can still be extracted by `issueIdPattern` for branch naming

### 2. Execute Core Stage N

Read and execute the corresponding core stage in [`workflow-stages.md`](../shared/workflow-stages.md).

If pre-extension produced `requirementContent`, pass it as `requirementContent` parameter when invoking Stage 1 (replacing default `$ARGUMENTS` text parsing).

### 3. Execute `EXTENSIONS_AFTER_N`

If extensions with `runAfter: N` exist, execute sequentially in array order (following the 6-step flow in "Extension Execution General Rules" below, including state persistence).

**When stage N ≥ 1** (`FEATURE_DIR` exists), extension artifacts write to `$FEATURE_DIR/extensions/<ext-id>/`.

---

## Extension Execution General Rules

**Mandatory Execution Rules (non-replaceable)**:

- For each extension with `enabled=true`, must actually invoke its `command` (e.g., `codespec.<ext-id>`).
- Prohibited to replace the extension with "faster/cheaper" alternative steps (e.g., lightweight validation only, static checks, or simplified scripts).
- If extension execution cost is high (e.g., requires additional runtime environment or long execution time), you may prompt for time cost and request user confirmation, but must still execute the original extension command unless user explicitly chooses "skip".

**Execution Logic**: For each extension, execute following steps:

1. **Skip Check**: If `.workflow-state.json` shows `stages["ext-<ext-id>"]` status as `completed`, skip this extension
2. **Create Artifact Directory** (when `FEATURE_DIR` exists): `mkdir -p "$FEATURE_DIR/extensions/<ext-id>/"`
3. **Mark Status as In Progress**:
   ```bash
   bash "$CLAUDE_PLUGIN_ROOT/scripts/bash/workflow-state.sh" update "ext-<ext-id>" "in_progress" '{}'
   ```
4. **Task Tool Invocation**: Execute extension command (e.g., `codespec.<ext-id>`)
5. **Validate Artifacts**: Check if `$FEATURE_DIR/extensions/<ext-id>/` directory generated expected files
6. **Failure Handling**: Handle per `onFailure` strategy (`block`: AskUserQuestion | `warn`: log warning and continue | `skip`: skip)
7. **State Persistence**:
   ```bash
   bash "$CLAUDE_PLUGIN_ROOT/scripts/bash/workflow-state.sh" update "ext-<ext-id>" "completed" '{"status":"ok","outputs":["$FEATURE_DIR/extensions/<ext-id>/"]}'
   ```

> Note: Replace `<ext-id>` with actual extension ID (e.g., `unit-test`). On failure, write status as `"failed"` or `"skipped"`.

**State persistence cannot be omitted. Extensions without written state will be re-executed on interruption recovery.**

Extension conventions: Command file `commands/codespec.<ext>.md`, artifacts write to `$FEATURE_DIR/extensions/<ext-id>/`.

---

## Core Stages

Read and execute core stages 1-6 in [`workflow-stages.md`](../shared/workflow-stages.md).

- **Monorepo mode** (default): Strictly execute per `workflow-stages.md`.
**You must read that file and strictly execute per the stage flow defined within.** Before and after each core stage, check and execute corresponding Hook Points extensions.

**⚠️ After all core stages complete, you must return to this file and continue executing "Pipeline End" and "Final Completion Report" below. Prohibited to stop directly after core stages complete.**

---

## Pipeline End (⚠️ Must execute regardless of whether extensions exist, cannot be skipped)

```bash
source "$CLAUDE_PLUGIN_ROOT/scripts/bash/memory-writer.sh"
memory_record_workflow "$ISSUE_ID" "${REVIEW_SCORE:-0}" "${SELECTED_SOLUTION:-unknown}" "${SPEC_PATH:-}" || true
```

Then clean up state file:

```bash
source "$CLAUDE_PLUGIN_ROOT/scripts/bash/workflow-state.sh"
workflow_state_cleanup "$FEATURE_DIR"
```

ℹ️ Parameter explanation: `ISSUE_ID`, `REVIEW_SCORE`, `SELECTED_SOLUTION`, `SPEC_PATH` come from output contracts of each stage. If variables not set, use above default values.

---

## Final Completion Report

The only location to output detailed content. Includes: basic information (issue ID + branch), core stage status (6 stages + solution name + review score), extension stage status, deliverable path list, next steps suggestions (validation → PR → review).

Report must add new "Requirements Coverage Results" section:
- Total `RQ-*` count
- Covered count
- Uncovered list (if any)
- User-approved exemption list (if any)

Next steps suggestions **must include**: If fine-tuning needed, can run `/codespec:refine` to adjust artifacts or code, system will selectively consolidate memory based on general value.

**After report output, workflow ends.**

---

## Interruption Recovery Mechanism

After each stage completes, persist to `.workflow-state.json` via `workflow_state_update`. Next execution of `/codespec:workflow` automatically detects and prompts for recovery.

| Last Completed Stage Before Interruption  | Recovery Starting Point          |
| --------------------- | ----------------- |
| None                    | Start from Stage 1     |
| stage1-specify        | Start from Stage 2     |
| stage2-clarify        | Start from Stage 3     |
| stage3-plan           | Start from Stage 4     |
| stage4-tasks          | Start from Stage 5     |
| stage5-implement      | Start from Stage 6     |
| stage6-review         | Start from post-extensions    |
| ext-{id}              | Continue from next extension  |
| All stages completed          | Output final report directly  |

## Error Handling

- Tool invocation failure → Retry once, still fails → AskUserQuestion
- Memory write failure → Do not block (`|| true`)
- Extension failure → Handle per `onFailure`
- Agent returns exception → Default value + warning
