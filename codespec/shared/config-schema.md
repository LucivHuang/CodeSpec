# Configuration Parsing Rules

When reading `.codespec/config/workflow.json`, parse according to the following rules.

## Loading Logic

1. Read `.codespec/config/workflow.json`
2. File does not exist → use all default values
3. File exists but JSON format is invalid → use default configuration and warn user
4. Missing fields → use default value for that field

## Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "version": {
      "type": "string",
      "default": "1.0"
    },
    "core": {
      "type": "object",
      "description": "Core configuration (technology stack agnostic)",
      "properties": {
        "specsDir": {
          "type": "string",
          "default": ".codespec/specs",
          "description": "Specification documents directory"
        },
        "language": { "type": "string", "default": "zh-CN", "description": "Output language" }
      }
    },
    "project": {
      "type": "object",
      "description": "Project-specific configuration",
      "properties": {
        "branchPattern": {
          "type": "string",
          "default": "feature/[feature-name]",
          "description": "Branch naming pattern. Placeholders: [feature-name], [ISSUE_ID]"
        },
        "issueIdPattern": {
          "type": "string",
          "default": "",
          "description": "Regex pattern for issue ID matching, only used to extract ID from input for branch naming. Empty string means issue ID extraction is disabled"
        }
      }
    },
    "extensions": {
      "type": "object",
      "description": "Extension configuration (Hook Points)",
      "properties": {
        "stages": {
          "type": "array",
          "default": [],
          "description": "Extension stage list. Each extension can declare which core stage to execute before/after via runBefore/runAfter",
          "items": {
            "type": "object",
            "required": ["id", "name", "enabled", "command"],
            "properties": {
              "id": { "type": "string", "description": "Extension unique identifier" },
              "name": { "type": "string", "description": "Display name" },
              "enabled": { "type": "boolean" },
              "command": {
                "type": "string",
                "description": "Extension command name, e.g. codespec.e2e-test"
              },
              "runBefore": {
                "type": "integer",
                "minimum": 1,
                "maximum": 6,
                "description": "Execute before the Nth core stage (1=spec generation, 2=requirements clarification, 3=solution design, 4=task breakdown, 5=code implementation, 6=code review). Mutually exclusive with runAfter, runBefore takes priority when both are set"
              },
              "runAfter": {
                "type": "integer",
                "minimum": 1,
                "maximum": 6,
                "description": "Execute after the Nth core stage. When neither runBefore nor runAfter is specified, defaults to runAfter: 6 (backward compatible)"
              },
              "onFailure": {
                "type": "string",
                "enum": ["block", "warn", "skip"],
                "default": "warn"
              },
              "config": { "type": "object", "description": "Custom configuration passed to extension" }
            }
          }
        }
      }
    }
  }
}
```

## Hook Points Description

Extensions declare execution position via `runBefore` and `runAfter` fields, with values being core stage numbers (1-6):

| Core Stage | Number | Stage Name |
|----------|------|--------|
| Spec Generation | 1 | stage1-specify |
| Requirements Clarification | 2 | stage2-clarify |
| Solution Design | 3 | stage3-plan |
| Task Breakdown | 4 | stage4-tasks |
| Code Implementation | 5 | stage5-implement |
| Code Review | 6 | stage6-review |

**Execution Rules**:
- `runBefore: 1` → Execute before stage 1 (common scenario: fetch requirement content from external system)
- `runAfter: 6` → Execute after stage 6 (common scenario: E2E testing, deployment)
- Both `runBefore` and `runAfter` specified → `runBefore` takes priority
- Neither specified → defaults to `runAfter: 6` (backward compatible)
- Multiple extensions at same hook point → execute in array order
- Invalid values (non 1-6 integer) → warn and skip that extension

**Data Passing for Pre-stage Extensions**:
- Extensions with `runBefore: 1` are used to fetch requirement content before Stage 1
- Extension returns `requirementContent` field via JSON contract
- Orchestrator passes this content to Stage 1 as requirement input
- If no pre-stage extension or extension doesn't return `requirementContent`, Stage 1 directly uses `$ARGUMENTS` text

## Default Values

When `workflow.json` does not exist or fields are missing:

```json
{
  "version": "1.0",
  "core": {
    "specsDir": ".codespec/specs",
    "language": "zh-CN"
  },
  "project": {
    "branchPattern": "feature/[feature-name]",
    "issueIdPattern": ""
  },
  "extensions": { "stages": [] }
}
```

## Extensions

- Command file: `commands/codespec.<ext>.md`
- Artifact directory: `<specsDir>/<branch>/extensions/<ext-id>/`
- Extension-specific configuration goes in extension's own `config` field, not in core configuration
- Workflow invokes via Task tool

## Failure Handling

| onFailure | Behavior                                    |
| --------- | --------------------------------------- |
| `block`   | Block, AskUserQuestion (retry/skip/abort) |
| `warn`    | Log warning, continue                          |
| `skip`    | Silently skip                                |
