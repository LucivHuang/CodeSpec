# Command Output Contracts

This file defines the standard JSON output contracts for CodeSpec core commands.

## Rules

- Command orchestrator treats these contracts as authoritative specifications
- Delegated commands/agents should output JSON on the last line
- When contract parsing fails, stop current stage and provide clear error

## `/codespec:specify`

```json
{ "spec_path": "...", "branch": "...", "summary": "...", "clarifications_needed": 0 }
```

## `/codespec:clarify`

```json
{ "spec_path": "...", "questions_answered": 3, "anchors_generated": 12 }
```

## `/codespec:plan`

```json
{ "plan_path": "...", "solutions": [{ "name": "...", "summary": "..." }], "recommended": "..." }
```

## `/codespec:tasks`

```json
{ "tasks_path": "...", "total_tasks": 15, "phases": 4, "parallel_opportunities": 5, "uncovered_requirement_count": 0 }
```

## `/codespec:implement`

```json
{
  "tasks_file": "$FEATURE_DIR/tasks.md",
  "files_changed": ["src/auth.ts", "src/api/login.ts"],
  "blocked_tasks": ["T015: Waiting for external API documentation"],
  "uncovered_requirements": ["RQ-007: Password reset functionality"]
}
```

**Field Description**:
- `tasks_file`: tasks.md path (completion status is counted from file, no longer counted by agent)
- `files_changed`: List of changed files
- `blocked_tasks`: Blocked tasks and reasons
- `uncovered_requirements`: List of uncovered requirements (should be empty)

## `/codespec:review`

```json
{
  "report_path": "...",
  "overall_score": 4.2,
  "p0_count": 0,
  "pass": true
}
```

**Optional Fields**: `p1_count`, `p2_count`, `dimensions` (detailed scores for each dimension)

## `/codespec:refine`

```json
{
  "refine_type": "spec|plan|tasks|code|preference",
  "modified_files": ["spec.md", "plan.md"],
  "memory_synced": true
}
```

**Optional Fields**: `memory_action`, `downstream_impact`

## Extension Command Contract (when invoked by `/codespec:workflow`)

For any configured extension command (e.g. `codespec.<ext-id>`), the last line JSON should include:

```json
{
  "status": "ok|failed|skipped",
  "executedCommand": "codespec.<ext-id>",
  "evidence": {
    "outputs": ["path/to/output"],
    "notes": "optional runtime note"
  }
}
```

## Pre-stage Extension Contract (extensions with `runBefore: 1`)

Extensions with `runBefore: 1` are used to fetch requirement content before Stage 1. In addition to standard extension contract fields, they can optionally return a `requirementContent` field:

```json
{
  "status": "ok",
  "executedCommand": "codespec.fetch-requirement",
  "requirementContent": "Fetched requirement text content...",
  "evidence": {
    "outputs": [],
    "notes": "Fetched from Jira PROJ-123"
  }
}
```

- `requirementContent` (optional): Fetched requirement text. Orchestrator uses it as requirement input for Stage 1.
- If `requirementContent` is empty or doesn't exist, Stage 1 falls back to using `$ARGUMENTS` text.
- When multiple `runBefore: 1` extensions return `requirementContent`, they are concatenated in array order (separated by newlines).
