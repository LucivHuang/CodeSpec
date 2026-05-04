---

description: "Feature implementation task list template"
---

# Task List: [FEATURE NAME]

**Input**: Design documents from `/.codespec/specs/[###-feature-name]/`
**Prerequisites**: plan.md (required), spec.md (required), code-exploration.md (if exists)

**Testing**: Test task generation rules follow `codespec/shared/tasks-format.md`.

## Format & Conventions

Standard format, field descriptions, and initial state rules are in `codespec/shared/tasks-format.md`.

## Path Conventions

Adjust based on project structure in plan.md, do not assume fixed directory layout.

## Phase 1: Setup Phase (Shared Infrastructure)

- [ ] T001 [Specific task + file path]

## Phase 2: Foundational Phase (Blocking Prerequisites)

⚠️ Do not proceed to user story implementation until this phase is complete.

- [ ] T00N [Specific task + file path]

**Checkpoint**: Foundation conditions ready

## Phase 3+: User Story N - [Title] (Priority: PN)

**Goal**: [Description] | **Independent Test**: [Verification method]

- [ ] T0XX [P?] [USN] Specific task + file path + reference code location

**Checkpoint**: Story N can run independently

## Phase N: Finalization & Cross-cutting Items

- [ ] TXXX Documentation supplement / cleanup / optimization / security hardening

## Dependencies & Execution Order

- **Setup → Foundational → User Stories (parallel or by priority) → Polish**
- Suggested order within each story: models → services → endpoints → integration
- Tasks marked [P] can be executed in parallel (different files, no dependencies)
- Each story should be independently completable and verifiable

## Notes

- Commit after completing each task or logical grouping
- Can pause and independently verify at any checkpoint
