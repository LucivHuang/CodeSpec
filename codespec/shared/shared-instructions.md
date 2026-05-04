# General Behavior Rules

## Paths

- Plugin assets: `$CLAUDE_PLUGIN_ROOT/` (before first use: `echo $CLAUDE_PLUGIN_ROOT`)
- User configuration: `.codespec/config/` | User memory: `.codespec/memory/`

## Output Language

From `workflow.json`'s `core.language` (default `zh-CN`). Chinese: body text/reports/prompts; English: code/paths/variables/terminology. When Task tool starts sub-agent, must specify language rules in prompt.

## User Interaction Strategy

**Default Behavior**: Execute automatically, do not pause waiting for user.

**Situations Requiring User Input** (only the following 5 cases):

1. **Requirements Clarification**: When ambiguities are found in specification (max 5 key questions)
2. **Solution Selection**: When multiple technical solutions are generated during design stage
3. **Task Confirmation**: After generating tasks.md, before starting code implementation
4. **P0 Issue Handling**: When code review finds critical issues (P0)
5. **Tool Call Failure**: After retries still fail, requiring user intervention

**Do not use AskUserQuestion or other pause mechanisms except in above situations.**

**Violation Examples** (prohibited):
- ❌ After generating spec in stage 1, asking "continue to next step?"
- ❌ After implementation complete in stage 5, asking "start review?"
- ❌ Before executing extension, asking "execute this extension?"

**Compliant Examples**:
- ✅ Stage 2 finds ambiguities → AskUserQuestion to clarify → wait for response then continue
- ✅ Stage 3 generates solutions → AskUserQuestion to select → wait for response then continue
- ✅ Stage 4 generates tasks → AskUserQuestion to confirm → wait for approval then continue

## Prohibit Fabrication

Functional scope > Security/Privacy > Business rules > User experience > Technical details — when key information is ambiguous, proactively ask according to "User Interaction Strategy".

## Technology Stack Agnostic

Core commands **must not hardcode technology stack**. All project knowledge is dynamically obtained from the following locations:

- `.codespec/config/workflow.json` - Branch specifications
- `.codespec/memory/constitution.md` - Coding standards, architecture constraints
- `.codespec/memory/project-context.json` - Technology stack, dependencies
- `.codespec/memory/code-patterns.json` - Validated patterns
- `.codespec/memory/user-preferences.json` - Solution preferences

## Context Loading Rules

Each stage agent reads the following documents as needed:

**Required Documents** (must exist before execution):
- `constitution.md` - Coding standards and project conventions
- `project-context.json` - Technology stack and dependency information

**Stage Documents** (by execution order):
- `spec.md` - Feature specification (generated in stage 1, read in subsequent stages)
- `plan.md` - Implementation plan (generated in stage 3, read in subsequent stages)
- `tasks.md` - Task list (generated in stage 4, read in stage 5)

**Optional Documents** (read if exists):
- `code-exploration.md` - Code exploration report
- `data-model.md` - Data model design
- `contracts/` - API contract definitions
- `research.md` - Technical research report
- `quickstart.md` - Quick start guide

Agent decides which documents to read based on task needs, no need to load all.

### Pre-requisite File Validation

Before any core command execution, must check `constitution.md` and `project-context.json`:

- Missing in `/codespec:workflow` → execute initialization in place then exit
- Missing in other commands → AskUserQuestion to prompt running initialization first, abort

## Progress Display

Core stages: `【{N}/6】Executing {name}...` | Extensions: `【Extension {index}/{total}】Executing {name}...`

## Execution Gates

Gates are mandatory requirements, must not be treated as advisory text.

| Gate | Check Method | Failure Behavior |
|------|---------|----------|
| Environment Check | `check-env.sh --json` | `passed=false` → stop immediately and display `errors` |
| Stage Gate | `gate-check.sh <gate> <feature_dir> --json` | `passed=false` → stop immediately, display `errors`, must not delegate to downstream agent |
| Contract Parsing | Last line JSON from delegated command/agent | Parse failure or missing required fields → stop current stage and report contract violation |
| Extension Integrity | For extensions with `enabled=true` | Must execute configured `command`, substitution prohibited; violation treated as policy failure, handled per `onFailure` |

## Artifact File Constraints

- All workflow state **only persisted via** `.workflow-state.json` (maintained by `workflow-state.sh`).
- **Prohibited** to create marker files like `.specify-done`, `.clarify-done`, `.plan-done` in specs directory or elsewhere.
- Legal artifact files limited to: `spec.md`, `plan.md`, `research.md`, `code-exploration.md`, `data-model.md`, `contracts/`, `quickstart.md`, `tasks.md`, `review-report.md`, `extensions/`, `.workflow-state.json`.

## Session Management

Task tool creates independent sessions to execute each stage.

## Shell Notes

Single quote arguments: `'I'\''m Groot'` or `"I'm Groot"`.
