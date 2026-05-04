---
description: Scan project and interactively generate constitution.md and project-context.json
handoffs:
  - label: Start workflow
    agent: codespec:workflow
    prompt: Project constitution is ready, start workflow
---

## User Input

```text
$ARGUMENTS
```

> General rules (output language, specification references, etc.) see [`../shared/shared-instructions.md`](../shared/shared-instructions.md)

**Preprocess `$ARGUMENTS`**: If user input is non-empty, record it first—URLs, file paths, and text descriptions will be processed together in step 2, no need to repeatedly ask for already provided content.

## Objective

Generate/update two core memory files for CodeSpec:

| File                                    | Content                                                         |
| --------------------------------------- | ------------------------------------------------------------ |
| `.codespec/memory/constitution.md`      | Project constitution: coding standards, architecture constraints, directory structure, naming conventions, Git workflow |
| `.codespec/memory/project-context.json` | Project context: tech stack, framework versions, dependencies, build tools, application list       |

## Execution Flow

### 1. Check Existing Files

```bash
mkdir -p .codespec/memory
CONSTITUTION_EXISTS=false
CONTEXT_EXISTS=false
[ -f ".codespec/memory/constitution.md" ] && CONSTITUTION_EXISTS=true
[ -f ".codespec/memory/project-context.json" ] && CONTEXT_EXISTS=true
echo "CONSTITUTION_EXISTS=$CONSTITUTION_EXISTS"
echo "CONTEXT_EXISTS=$CONTEXT_EXISTS"
```

- If files exist → Enter **update mode**: read existing content, only modify user-specified parts
- If files don't exist → Enter **create mode**: full scan + interactive generation

### 2. Ask User for Conventions

If `$ARGUMENTS` already contains convention information (URL links, file paths, or text descriptions), process this content first:

- URL links (matching `https?://`) → Use WebFetch to get page content, extract convention information
- Local file paths (file exists) → Use Read to read file content, extract convention information
- Plain text description → Record directly as convention input

Then use AskUserQuestion to ask user **once**:

> Does the project have special conventions to follow? For example:
>
> - Company/team coding standards
> - Branch naming conventions, commit conventions
> - Component structure conventions, directory organization conventions
> - Other special requirements
>
> You can describe directly, or provide URLs or local file paths to convention documents (multiple supported). If none, just reply "None", and I'll automatically extract from project code.

**If `$ARGUMENTS` already provided sufficient convention information**, note the received content when asking, only follow up on whether there are additions.

**Process user response:**

- If contains URL links → Use WebFetch to get content, extract convention information
- If contains local file paths → Use Read to read content, extract convention information
- If plain text description → Record directly as convention input
- If replies "None" or similar meaning → Skip, rely entirely on automatic scanning

Record user-provided convention information as `USER_CONVENTIONS`, as **priority input** for subsequent generation.

### 3. Automatically Scan Project Structure

Scan project root directory, **supplement** information not covered by `USER_CONVENTIONS` (best effort, skip if file doesn't exist):

| Scan Category                                                        | Extracted Information                           |
| --------------------------------------------------------------- | ---------------------------------- |
| Project manifests (package.json, Cargo.toml, go.mod, pyproject.toml, etc.) | Project name, framework, dependencies, scripts, package manager |
| Language configs (tsconfig.json, .python-version, etc.)                   | Language version, compilation options                 |
| Workspaces (pnpm-workspace.yaml, lerna.json, etc.)                    | Subproject list, monorepo structure          |
| Code standards (.eslintrc*, .prettierrc*, .editorconfig, etc.)          | Standard rules                           |
| Build tools (vite.config._, webpack.config._, Makefile, etc.)        | Build tools and configuration                     |
| CI/CD + deployment (CI config files, Dockerfile, etc.)                      | Continuous integration, deployment methods                 |
| Commit conventions (commitlint.config.\*, etc.)                             | Commit conventions                           |
| Project docs + directories (README.md, ls first 2 levels)                        | Description, conventions, organization patterns               |

> Above are examples, actual tech stack automatically identified based on existing project files.

**Merge rules**: User-provided > Scanned inference. Scanning only supplements objective facts not mentioned by user.

### 4. Generate Files

#### 4.1 Generate `project-context.json`

Structured project context, fields added/removed based on actual tech stack:

```json
{
  "projectInfo": {
    "name": "",
    "type": "monorepo|single-app|multi-module",
    "language": "",
    "framework": "",
    "packageManager": "",
    "modules": []
  },
  "techStack": { "<category>": { "framework": "", "libraries": [] } },
  "build": { "tool": "", "packageManager": "" },
  "quality": { "linter": "", "formatter": "", "testing": "" },
  "lastUpdated": "<ISO>"
}
```

#### 4.2 Generate `constitution.md`

Based on scan + user input, includes (add/remove based on actual situation): core principles, project structure conventions, code organization conventions, Git workflow conventions, code style, other conventions.

### 5. Output Confirmation

After writing files, output summary: list of generated files, detected project information (framework/language/sub-apps/build tools), convention source statistics (scan/interactive).
