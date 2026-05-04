# Hook Points Extension

CodeSpec's core pipeline is not bound to any external systems. To integrate with requirement management platforms, design tools, CI/CD, etc., insert custom extensions before/after any core stage through Hook Points.

## Core Concepts

The 6 core stages have fixed numbers:

| Number | Stage |
|--------|-------|
| 1 | Spec Generation |
| 2 | Requirement Clarification |
| 3 | Solution Design |
| 4 | Task Breakdown |
| 5 | Code Implementation |
| 6 | Code Review |

Extensions declare execution position through `runBefore` or `runAfter`:

```
[Pre-extension] → Stage1 → [Extension] → Stage2 → [Extension] → ... → Stage6 → [Post-extension]
```

## Configuration Method

Register in `extensions.stages` of `.codespec/config/workflow.json`:

```json
{
  "extensions": {
    "stages": [
      {
        "id": "fetch-requirement",
        "name": "Fetch requirement from Jira",
        "enabled": true,
        "command": "codespec.fetch-requirement",
        "runBefore": 1,
        "onFailure": "block"
      }
    ]
  }
}
```

### Field Description

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | ✅ | Extension unique identifier |
| `name` | string | ✅ | Display name |
| `enabled` | boolean | ✅ | Whether enabled |
| `command` | string | ✅ | Command name under `.claude/commands/` |
| `runBefore` | integer (1-6) | ❌ | Execute before the Nth core stage |
| `runAfter` | integer (1-6) | ❌ | Execute after the Nth core stage |
| `onFailure` | string | ❌ | Failure strategy: `block`/`warn`/`skip` (default `warn`) |
| `config` | object | ❌ | Custom configuration passed to extension |

**Rules**:
- `runBefore` and `runAfter` are mutually exclusive; when both are set, `runBefore` takes precedence
- When neither is filled, defaults to `runAfter: 6` (backward compatible)
- Invalid values (non 1-6 integers) → warning and skip
- When multiple extensions exist at the same hook point, execute in array order

### Failure Strategies

| onFailure | Behavior |
|-----------|----------|
| `block` | Block, ask user: retry / skip / terminate |
| `warn` | Log warning, continue subsequent flow |
| `skip` | Silently skip |

## Common Scenarios

| Scenario | Hook Point | Description |
|----------|------------|-------------|
| Fetch requirements from ticketing system | `runBefore: 1` | Jira, Linear, Feishu Projects, etc. |
| Requirement document conversion | `runBefore: 1` | Confluence, Yuque, Notion, etc. |
| Design mockup analysis | `runBefore: 1` | Figma, Sketch, etc. |
| Technical research before solution design | `runBefore: 3` | Technology selection evaluation, competitor analysis |
| Environment preparation before implementation | `runBefore: 5` | Database migration, environment startup |
| E2E / integration testing | `runAfter: 6` | Execute end-to-end tests after review passes |
| Automatic deployment | `runAfter: 6` | Deploy to pre-production/staging environment |
| PR / MR creation | `runAfter: 6` | Automatically create Pull Request |

## Writing Extensions

### 1. Create Command File

Create `codespec.<ext-id>.md` in the project's `.claude/commands/` directory:

```markdown
---
description: Fetch ticket details from Jira
---

## User Input

\```text
$ARGUMENTS
\```

## Execution Steps

1. Extract ticket number from $ARGUMENTS
2. Call Jira API to get ticket details
3. Format as structured requirement text
4. Output JSON contract
```

### 2. Output Contract

The last line of all extensions must output JSON:

```json
{
  "status": "ok",
  "executedCommand": "codespec.<ext-id>",
  "substituted": false,
  "executionToken": "${CODESPEC_EXECUTION_TOKEN}",
  "evidence": {
    "outputs": ["path/to/output"],
    "notes": "optional note"
  }
}
```

**executionToken field (required)**:
- The orchestrator generates a unique token before calling the extension and sets the environment variable `CODESPEC_EXECUTION_TOKEN`
- Extensions must return this token in JSON output (directly use the `${CODESPEC_EXECUTION_TOKEN}` environment variable)
- The orchestrator verifies that the returned token matches the expected value to ensure the extension was actually executed
- Token mismatch or absence will cause extension execution to fail

### 3. Special Fields for Pre-Extensions

Extensions with `runBefore: 1` can additionally return `requirementContent`, which the orchestrator will use as the requirement input for Stage 1:

```json
{
  "status": "ok",
  "executedCommand": "codespec.fetch-jira",
  "substituted": false,
  "executionToken": "${CODESPEC_EXECUTION_TOKEN}",
  "requirementContent": "Retrieved requirement text...",
  "evidence": {
    "outputs": [],
    "notes": "Fetched from Jira PROJ-123"
  }
}
```

- If `requirementContent` is empty or doesn't exist → Stage 1 falls back to using `$ARGUMENTS` text
- Multiple `runBefore: 1` extensions return `requirementContent` → concatenate in array order

### 4. Artifact Storage

- Extensions with `runBefore: 1`: Pass data through JSON contract (FEATURE_DIR not yet created at this point)
- Other extensions: Write artifacts to `$FEATURE_DIR/extensions/<ext-id>/`

## Complete Example

Extension commands are written the same way as regular Claude Code custom commands, just ensure the last line outputs a JSON contract. See the "Writing Extensions" section above.
