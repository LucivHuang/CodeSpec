---
description: Post-workflow refinement command — adjust artifacts, update code, extract and deposit memory by value
handoffs:
  - label: Re-run full workflow
    agent: codespec:workflow
    prompt: Re-run full workflow
---

## User Input

```text
$ARGUMENTS
```

You **must** consider the user input (if non-empty) before proceeding.

> General rules (output language, specification references, etc.) see [`../shared/shared-instructions.md`](../shared/shared-instructions.md)

## Overview

`/codespec:refine` is used for refinement **after workflow completion**. Users may want to adjust requirements, modify plans, update code, or record experience preferences. Only write to memory system when this adjustment can be abstracted as reusable experience.

## Execution Flow

### 1. Initialization

**⚠️ Must first confirm `$CLAUDE_PLUGIN_ROOT`.** If empty, run `echo $CLAUDE_PLUGIN_ROOT` once to get it. If still empty (e.g., non-plugin context), search upward from repository `.codespec/` to infer.

```bash
bash "$CLAUDE_PLUGIN_ROOT/scripts/bash/refine-init.sh"
```

**Process initialization result:**

- `ERROR: Feature directory not found` → Terminate, prompt user to run `/codespec:workflow` first.
- `ACTIVE_WORKFLOW=true` → AskUserQuestion: "There is an active workflow, suggest completing it before refining. Continue anyway?" Only proceed after user confirmation.

### 2. Analyze Refinement Intent

Determine user's adjustment type from `$ARGUMENTS` and context:

| Intent Keywords | Type | Target Artifact |
|-----------|------|---------|
| requirement/spec/scope | `spec` | spec.md |
| plan/design/architecture | `plan` | plan.md |
| task/breakdown/tasks | `tasks` | tasks.md |
| code/implementation/bug/fix | `code` | source code files |
| preference/habit/future/remember | `preference` | user-preferences.json |

If intent is unclear, AskUserQuestion to ask user:

> Which aspect do you want to adjust?
> 1. Requirement specification (spec.md)
> 2. Technical plan (plan.md)
> 3. Task breakdown (tasks.md)
> 4. Code implementation
> 5. Record preference/experience (memory only, no code changes)

### 3. Execute Adjustment

#### 3.1 Requirement Refinement (type=spec)

1. Read existing `$FEATURE_DIR/spec.md`
2. Locate sections to modify based on user description
3. Directly modify spec.md (add `<!-- refined: YYYY-MM-DD -->` comment marker at modification)
4. If functional scope or success criteria modified, prompt user to consider re-running `/codespec:plan`

#### 3.2 Plan Refinement (type=plan)

1. Read existing `$FEATURE_DIR/plan.md` and `$FEATURE_DIR/spec.md`
2. Adjust plan content based on user description
3. Directly modify plan.md (add modification marker)
4. If plan changes affect task breakdown, prompt user to consider re-running `/codespec:tasks`

#### 3.3 Task Refinement (type=tasks)

1. Read existing `$FEATURE_DIR/tasks.md`
2. Supported operations: add task, delete task, adjust priority, modify description, merge/split tasks
3. Directly modify tasks.md, maintain tasks-format specification
4. If incomplete tasks had implementation approach modified, prompt user to consider re-running `/codespec:implement`

#### 3.4 Code Refinement (type=code)

1. Read `$FEATURE_DIR/tasks.md` to get list of implemented files
2. Locate code to modify based on user description
3. Apply code changes
4. If changes involve new patterns or best practices:

```bash
source "$CLAUDE_PLUGIN_ROOT/scripts/bash/memory-writer.sh"
memory_record_code_pattern "$TYPE" "$NAME" "5.0" "$FILE_PATH" "$LIBS" || true
```

#### 3.5 Preference Recording (type=preference)

Do not modify any artifacts or code. Directly proceed to step 4 experience extraction process.

### 4. Experience Extraction and Conditional Memory (all types must judge)

Regardless of adjustment type, after completing adjustment you (AI) must autonomously judge: **Does this modification contain reusable experience?**

#### Judgment Principles

Experience worth recording:
- Can be abstracted as general strategy, convention, standard, tradeoff principle
- Can be directly reused in similar future scenarios
- Reflects user's long-term preferences or team practices

Information not worth recording:
- One-time changes, temporary patches, modifications only valid for current branch/file
- Pure bug fixes (no design-level insights)
- Insufficient information to form reusable conclusions

#### If judged valuable → Write to memory

After extracting one-sentence experience, call script to write:

```bash
source "$CLAUDE_PLUGIN_ROOT/scripts/bash/memory-writer.sh"

memory_record_refinement \
    "$REFINE_TYPE" \
    "$DESCRIPTION" \
    "$REASONING" \
    "$INSIGHT" \
    "$APPLICABILITY" \
    "$CONFIDENCE" || true
```

Parameter descriptions:
- `REFINE_TYPE`: adjustment type (spec / plan / tasks / code / preference)
- `DESCRIPTION`: summary of user's adjustment content (one sentence)
- `REASONING`: reason for adjustment or user preference (why change this way)
- `INSIGHT`: AI-extracted general experience (one sentence, avoid task details)
- `APPLICABILITY`: experience applicability scope (project / team / global)
- `CONFIDENCE`: experience confidence level (0.0-1.0)

Set `MEMORY_SYNCED=true`, `MEMORY_ACTION="recorded"`.

#### If judged not valuable → Skip

Do not call script. Set `MEMORY_SYNCED=false`, `MEMORY_ACTION="skipped_low_value"`.

### 5. Report

Output concise adjustment report:

- Adjustment type
- List of modified files
- Memory sync status (recorded / skipped_low_value)
- Follow-up suggestions (whether need to re-run downstream commands)

## Output Contract

Last line JSON:

```json
{
  "refine_type": "spec|plan|tasks|code|preference",
  "modified_files": ["path/to/file"],
  "memory_synced": true,
  "memory_action": "recorded|skipped_low_value",
  "downstream_impact": "none|suggest-replan|suggest-retask|suggest-reimplement"
}
```

## Key Principles

- **Only change what user requested** — Don't expand adjustment scope
- **Preserve artifact history** — Add comment markers at modifications, don't delete existing valid content
- **AI autonomously judges memory value** — You judge whether reusable, then extract and write, avoid noise
- **Prompt downstream impact** — If adjustment may cause downstream artifacts to become outdated, proactively prompt
