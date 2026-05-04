---
description: Create or update feature specification from natural language feature description.
handoffs:
  - label: Build technical solution
    agent: codespec:plan
    prompt: Create solution for the specification. I'm building...
  - label: Clarify specification requirements
    agent: codespec:clarify
    prompt: Clarify specification requirements
    send: true
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider user input (if not empty) before proceeding.

> General rules (output language, specification references, etc.) see [`../shared/shared-instructions.md`](../shared/shared-instructions.md)

Output contract see [`../shared/command-contracts.md`](../shared/command-contracts.md).

## Plugin Root Resolution

Before calling any `scripts/bash/*` or `templates/*`, ensure `CLAUDE_PLUGIN_ROOT` is valid:

```bash
# If CLAUDE_PLUGIN_ROOT is not set or invalid, try to resolve
if [[ -z "${CLAUDE_PLUGIN_ROOT:-}" || ! -d "$CLAUDE_PLUGIN_ROOT/scripts/bash" ]]; then
  source "$(dirname "$(dirname "${BASH_SOURCE[0]}")")/scripts/bash/common.sh"
  resolve_plugin_root || exit 1
fi
```

## Execution Flow

**Input**: Feature description text entered by user after `/codespec:specify`

**Prerequisites**: None (first stage)

**Execution Steps**:

1. **Create branch and artifact directory**
   - Generate short name (2-4 words, action-noun format, avoid branch prefix word duplication)
   - Extract issue ID from user input (if `issueIdPattern` is configured)
   - Call `create-new-feature.sh` to create branch and directory structure
   - Parse returned BRANCH_NAME, SPEC_FILE, FEATURE_NAME, ISSUE_ID

2. **Delegate to requirements-analyst agent to generate specification**
   - Pass in: requirementContent, SPEC_FILE, BRANCH, specTemplate, OUTPUT_LANGUAGE
   - Agent responsible for: extracting requirements, identifying ambiguities, generating structured specification document
   - Output contract: see `command-contracts.md`

3. **Validate artifacts**
   - spec.md contains required sections (user scenarios, requirements, success criteria)
   - No implementation details (technology-agnostic)
   - Success criteria are measurable
   - [NEEDS CLARIFICATION] markers ≤ 5

**Artifacts**:
- `spec.md` - Feature specification
- `FEATURE_DIR` - Feature directory path
- `BRANCH` - Git branch name

**Next Steps**:
- Has ambiguities → `/codespec:clarify`
- No ambiguities → `/codespec:plan`

**Domain Knowledge**: Requirements analysis expertise see [`../agents/requirements-analyst.md`](../agents/requirements-analyst.md)
