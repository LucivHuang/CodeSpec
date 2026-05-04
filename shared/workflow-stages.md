# Core Stages

> This file is loaded by [`workflow.md`](../commands/workflow.md). After completing all core stages, return to workflow.md to continue extension pipeline and final report.

---

## Core Stage 1: Spec Generation

> **Recovery Rule**: If stage1-specify status is completed, read specPath and branch from its outputs, skip this stage.

### 1.1 Get Requirements

**Requirement Content Source (by priority)**:

1. **Pre-stage Extension Output**: If extensions with `runBefore: 1` returned `requirementContent` (passed in by orchestrator), directly use that content as the primary requirement source. Other text in `$ARGUMENTS` serves as supplementary explanation, appended to the end.
2. **Direct User Input**: When no pre-stage extension output exists, directly use `$ARGUMENTS` text as requirement content.

**Issue ID Extraction (for branch naming only)**: Use `PROJECT_ISSUE_PATTERN` to extract issue number from `$ARGUMENTS` (if any), pass to `create-new-feature.sh --issue-id`. Issue ID is only used for generating branch name, does not trigger any external system calls.

Abort when user input is empty.

### 1.2 Generate Spec

Task tool → `/codespec:specify`, pass in requirementContent + OUTPUT_LANGUAGE. Parse output contract according to `command-contracts.md`.

**⚠️ Critical: Derive FEATURE_DIR (cannot skip)**

`/codespec:specify` internally calls `create-new-feature.sh` to create git branch and artifact directory. You must derive path variables from its output contract:

```
SPEC_PATH = contract's spec_path
BRANCH   = contract's branch
FEATURE_DIR = dirname(SPEC_PATH)   ← i.e. $SPECS_DIR/$BRANCH
```

**Do not create directories yourself using issue ID or other names** — `FEATURE_DIR` can only come from `create-new-feature.sh` output. If the path returned by specify doesn't contain branch pattern (e.g. `feature/name`), it indicates execution anomaly, must abort and prompt user.

### 1.3 Persist

If state file not created, explicitly initialize first; then write completion status:

```bash
if [[ ! -f "$FEATURE_DIR/.workflow-state.json" ]]; then
  bash "$CLAUDE_PLUGIN_ROOT/scripts/bash/workflow-state.sh" create "${ISSUE_ID:-}" "$BRANCH" "$FEATURE_DIR"
fi
bash "$CLAUDE_PLUGIN_ROOT/scripts/bash/workflow-state.sh" update "stage1-specify" "completed" '{"specPath":"...","branch":"..."}'
```

---

## Core Stage 2: Requirements Clarification

> **Recovery Rule**: If stage2-clarify status is completed, read specPath from its outputs, skip this stage.

### 2.0 Gate Check

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/bash/gate-check.sh" specify-done "$FEATURE_DIR" --json
```

If `passed=false`, abort.

### 2.1 Requirements Clarification (mandatory pause point)

First mark stage as started:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/bash/workflow-state.sh" update "stage2-clarify" "in_progress" '{}'
```

Task tool → `/codespec:clarify`, pass in specPath. Clarify ambiguities via AskUserQuestion (max 5), **must wait for user response**.

### 2.2 Validate Requirements Anchors (prevent loss, must execute)

`/codespec:clarify` (step 6) is already responsible for generating requirements anchors. Here **only validate**:

1. Check if `spec.md` contains `## Requirements Baseline` section
2. Check if it contains at least 1 requirement entry in `RQ-*` format
3. If anchors are missing or empty → error and abort, prompt to re-run `/codespec:clarify`

This anchor serves as mandatory input for subsequent stages, no stage may skip it.

### 2.3 Persist

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/bash/workflow-state.sh" update "stage2-clarify" "completed" '{"specPath":"..."}'
```

---

## Core Stage 3: Solution Design

> **Recovery Rule**: If stage3-plan status is completed, read planPath and selectedSolution from its outputs, skip this stage.

### 3.0 Gate Check

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/bash/gate-check.sh" clarify-done "$FEATURE_DIR" --json
```

If `passed=false`, abort.

### 3.1 Execute Design

First mark stage as started:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/bash/workflow-state.sh" update "stage3-plan" "in_progress" '{}'
```

Task tool → `/codespec:plan`, pass in specPath (which contains "Requirements Baseline" section). Parse output contract according to `command-contracts.md`.

### 3.2 Solution Confirmation (mandatory pause point)

AskUserQuestion to let user choose solution (mark recommended with `(Recommended)`), **must wait for explicit user response**.

### 3.3 Persist

`memory_record_solution_preference` records solution preference, then execute:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/bash/workflow-state.sh" update "stage3-plan" "completed" '{"planPath":"...","selectedSolution":"..."}'
```

---

## Core Stage 4: Task Breakdown

> **Recovery Rule**: If stage4-tasks status is completed, read tasksPath from its outputs, skip this stage.

### 4.0 Gate Check

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/bash/gate-check.sh" plan-done "$FEATURE_DIR" --json
```

If `passed=false`, abort.

### 4.1 Generate Tasks

First mark stage as started:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/bash/workflow-state.sh" update "stage4-tasks" "in_progress" '{}'
```

Task tool → `/codespec:tasks`, pass in specPath + planPath (and explicitly require reading `RQ-*` anchors in spec). Parse output contract according to `command-contracts.md`.

### 4.2 Task Confirmation (mandatory pause point)

AskUserQuestion to show user tasks.md summary (total tasks, phase breakdown, parallelizable tasks count), **must wait for explicit user approval** before continuing. User can request task adjustments and regeneration.

### 4.3 Persist

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/bash/workflow-state.sh" update "stage4-tasks" "completed" '{"tasksPath":"..."}'
```

---

## Core Stage 5: Code Implementation

> **Recovery Rule**: If stage5-implement status is completed, read tasksPath from its outputs, skip this stage.

### 5.0 Gate Check

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/bash/gate-check.sh" tasks-done "$FEATURE_DIR" --json
```

If `passed=false`, abort.

### 5.1 Execute Implementation

First mark stage as started:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/bash/workflow-state.sh" update "stage5-implement" "in_progress" '{}'
```

Task tool → `/codespec:implement`, pass in tasksPath. Parse output contract according to `command-contracts.md`.

### 5.2 Validate Completion

Count `- [x]` vs `- [ ]` in tasksPath.

**⚠️ Task Marking Consistency Validation (must execute)**:

1. Read tasks.md, count actual `- [x]` quantity
2. Compare with `completed_tasks` field in JSON returned by agent
3. If inconsistent:
   - Log warning: `Task marking inconsistent: agent reported {completed_tasks} tasks completed, but tasks.md marked {actual_marked}`
   - **Use tasks.md actual marking as authoritative** (code changes are factual evidence)
   - Continue subsequent process (don't block workflow)

**Task Completion Check**:

Not all completed → AskUserQuestion to show incomplete task list, let user choose: continue implementation / adjust plan / skip remaining tasks.

**Requirements Coverage Validation (must execute)**:

Cross-check `RQ-*` in `spec.md` with tasks.md coverage matrix and implementation results.

When requirement gaps exist, must first supplement tasks and implement, or get explicit user approval to defer. Cannot declare stage 5 complete before handling gaps.

### 5.3 Persist

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/bash/workflow-state.sh" update "stage5-implement" "completed" '{"tasksPath":"..."}'
```

---

## Core Stage 6: Code Review

> **Recovery Rule**: If stage6-review status is completed, read reportPath and overallScore from its outputs, skip this stage.

### 6.0 Gate Check

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/bash/gate-check.sh" implement-done "$FEATURE_DIR" --json
```

If `passed=false`, abort.

### 6.1 Execute Review

First mark stage as started:

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/bash/workflow-state.sh" update "stage6-review" "in_progress" '{}'
```

Task tool → `/codespec:review`, pass in FEATURE_DIR. Parse output contract according to `command-contracts.md`.

### 6.2 Review Result Handling (conditional pause point)

Parse JSON returned by `/codespec:review`:

| Situation | Handling |
|------|------|
| `pass=true` (P0 = 0) | Show score summary, continue workflow |
| `pass=false` (P0 > 0) | **Mandatory pause**: AskUserQuestion to show P0 issue list, let user choose |

**User Options When P0 > 0**:

- **Fix and re-review** → Prompt user to fix (can run `/codespec:refine`), re-execute stage 6 after fixing
- **Waive and continue** → Mark `[User Waived]` in report, continue workflow
- **Abort workflow** → Abort

### 6.3 Memory Consolidation

High-value patterns discovered in review (e.g. anti-patterns, new naming conventions) are written to `code-patterns.json` via `memory_record_code_pattern`:

- Only record excellent patterns with score ≥ 4.5
- Record anti-patterns that repeatedly appear in review (write to `antiPatterns.avoided`)
- Write failure doesn't block (`|| true`)

### 6.4 Persist

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/bash/workflow-state.sh" update "stage6-review" "completed" '{"reportPath":"...","overallScore":...,"p0Count":...,"pass":...}'
```

---

## ⚠️ All Core Stages Complete — Must Return to workflow.md

**You have completed all 6 core stages. Now you must immediately return to [`workflow.md`](../commands/workflow.md) to continue executing the following necessary steps:**

1. **Extension Pipeline**: Execute remaining `EXTENSIONS_AFTER_6` and `EXTENSIONS_LEGACY`
2. **Pipeline End**: Record memory + clean up state file
3. **Final Completion Report**: Output detailed report

**Do not stop here. Without outputting final completion report, workflow is not finished.**
