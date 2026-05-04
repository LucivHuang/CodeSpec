# Configuration Reference

Configuration file `.codespec/config/workflow.json` is optional. If not created, all default values are used, and it can run with zero configuration.

## Complete Configuration Example

```json
{
  "core": {
    "specsDir": ".codespec/specs",
    "language": "en-US"
  },
  "project": {
    "branchPattern": "feature/[feature-name]",
    "issueIdPattern": "[A-Z]+-[0-9]+"
  },
  "extensions": {
    "stages": []
  }
}
```

## Configuration Item Description

### core — Core Configuration

| Config Item | Type | Default | Description |
|-------------|------|---------|-------------|
| `specsDir` | string | `.codespec/specs` | Specification document storage directory |
| `language` | string | `en-US` | Output language (affects language of all artifact documents and interactive prompts) |

### project — Project Configuration

| Config Item | Type | Default | Description |
|-------------|------|---------|-------------|
| `branchPattern` | string | `feature/[feature-name]` | Branch naming pattern |
| `issueIdPattern` | string | `[A-Z]+-[0-9]+` | Issue ID matching regex, only used to extract ID from input to splice into branch name |

### extensions — Extension Configuration

| Config Item | Type | Default | Description |
|-------------|------|---------|-------------|
| `stages` | object[] | `[]` | Extension stage list. See [Hook Points Extension](hook-points.md) for details |

## Branch Naming Pattern

`branchPattern` supports the following placeholders:

| Placeholder | Source | Description |
|-------------|--------|-------------|
| `[feature-name]` | Auto-generated from feature description (2-4 words) | Always exists |
| `[ISSUE_ID]` | Extracted from input using `issueIdPattern` | When not found, placeholder and preceding separator are removed |

**Examples**:

| Input | branchPattern | Generated Branch Name |
|-------|---------------|----------------------|
| `PROJ-123 user login` | `feature/[ISSUE_ID]_[feature-name]` | `feature/PROJ-123_user-login` |
| `user login` | `feature/[feature-name]` | `feature/user-login` |
| `PROJ-123 user login` | `feat/[ISSUE_ID]-[feature-name]` | `feat/PROJ-123-user-login` |

## Memory Files

Auto-generated on first run of `/codespec:workflow` or `/codespec:constitution`:

| File | Description |
|------|-------------|
| `.codespec/memory/constitution.md` | Project constitution: coding standards, architecture constraints, directory structure, naming rules, Git workflow |
| `.codespec/memory/project-context.json` | Project context: tech stack, framework versions, dependencies, build tools |
| `.codespec/memory/user-preferences.json` | User preferences: design solution tendencies (auto-accumulated) |
| `.codespec/memory/code-patterns.json` | Code patterns: high-quality implementation patterns (auto-accumulated) |
| `.codespec/memory/workflow-history.json` | Workflow history: execution records (auto-accumulated) |

The first two are required to start the workflow; the last three auto-accumulate and don't block if missing.

## Default Values

Complete default configuration when `workflow.json` is not created:

```json
{
  "version": "1.0",
  "core": {
    "specsDir": ".codespec/specs",
    "language": "en-US"
  },
  "project": {
    "branchPattern": "feature/[feature-name]",
    "issueIdPattern": "[A-Z]+-[0-9]+"
  },
  "extensions": { "stages": [] }
}
```
