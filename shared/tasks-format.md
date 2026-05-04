# Tasks Format Specification

This file is the single source of truth for `tasks.md` generation and validation.

## Standard Format

```markdown
- [ ] T001 [P] [US1] Implement login() function in src/auth/login.ts, refer to authentication pattern in code-exploration.md#L45
```

**Format Description**:
- `- [ ]`: Incomplete task (must be `[ ]` when generated, changed to `[x]` when completed)
- `T001`: Task ID (numbered by execution order)
- `[P]`: Parallelizable task marker (optional)
- `[US1]`: User story identifier (optional)
- Description: Includes file path, implementation point, reference code location

## Test Task Rules

- If spec.md or constitution.md explicitly requires testing: generate test tasks
- If no testing requirements are defined: add a comment at the end of tasks.md:
  ```html
  <!-- Note: Specification does not require testing, test task generation skipped -->
  ```

## Constraints

- File paths use absolute paths from repository root
- If code-exploration.md exists, tasks should reference code locations within it
- Task descriptions must be executable and not depend on implicit context
