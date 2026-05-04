# Comparison and Design Philosophy

This document details the differences between CodeSpec and other AI coding tools, along with the underlying design principles.

## Tool Comparison

### Comparison with Non-SDD Workflows

Taking Anthropic's official `feature-dev` as an example, it represents an exploratory development paradigm, fundamentally different from CodeSpec's Specification-Driven Development (SDD).

| Dimension | feature-dev | CodeSpec |
|---|---|---|
| Development Paradigm | Exploratory, understand while implementing | SDD, specification-driven full workflow |
| Suitable Scenarios | Small to medium features in single session | Large feature development across sessions |
| Onboarding Cost | Zero config, one command to start | First-time use, plugin auto-initializes project standards |
| Requirement Management | Verbal confirmation then direct exploration | Structured spec.md + interactive clarification |
| Task Tracking | None, direct implementation | tasks.md with item-by-item execution and progress tracking |
| Interruption Recovery | Not supported, restart from scratch | Auto-persisted state, resume from checkpoint |
| Project Memory | None | Auto-accumulates team/personal coding standards, code patterns, preferences |

### Comparison with Other SDD Workflows

Here we use pain points collected from SpecKit and OpenSpec communities as comparison dimensions.

#### 1. Spec Drift

**Problem**: 8-month debate on "spec vs code as source of truth" with no consensus. Specs become outdated after writing, and after multiple iterations, the spec chain becomes unread historical archives.

- **SpecKit**: Unresolved
- **OpenSpec**: Partially mitigated with archive command
- **CodeSpec**: Spec is positioned as an AI-to-human understanding verification protocol, not a permanent system description. Disposable after use is allowed.

#### 2. Missing Post-Implementation Modification Flow

**Problem**: No official post-implementation modification flow. Users don't know what to do when issues are found after implementation.

- **SpecKit**: None
- **OpenSpec**: None
- **CodeSpec**: Minor tweaks can use the refine command; redesign needs can execute plan and other commands independently

#### 3. Brownfield Project Adaptation

**Problem**: SDD tools generally assume Greenfield (new projects), with poor adaptation to existing codebases.

- **SpecKit**: Indeed no adaptation for Brownfield scenarios
- **OpenSpec**: Same as above
- **CodeSpec**: Plan stage has built-in **code-exploration**. AI analyzes existing code structure before proposing solutions, suitable for both Greenfield and Brownfield

#### 4. Unidirectional Pipeline Cannot Roll Back

**Problem**: As stated. Original quote: "Do we back out and update the specs/plan and redo everything?"

- **SpecKit**: No state machine, basically cannot roll back
- **OpenSpec**: Same as above
- **CodeSpec**: Supports restarting from any stage by executing commands independently, no need to start the complete workflow from scratch

### AI Coding Tool Ecosystem Comparison

| Tool | Positioning | Core Capabilities | Use Cases | Limitations |
|---|---|---|---|---|
| **GitHub Copilot** | Code completion assistant | Line/function-level completion, Chat dialogue | Daily coding, quick completion | No tool calling, no Agent system, cannot orchestrate complex workflows |
| **Cursor** | AI-first IDE | Multi-file editing, Composer mode | Rapid prototyping, refactoring | Closed source, no plugin system, fixed workflow, high cost |
| **Windsurf (Codeium)** | AI IDE | Cascade multi-step editing | Similar to Cursor scenarios | Workflow not customizable, no Agent orchestration capability |
| **Tongyi Lingma** | Domestic code assistant | Code completion, Chat, unit testing | Domestic users, Chinese-friendly | Weak tool calling capability, no complex workflow support |
| **CodeGeeX** | Open-source code assistant | Multi-language completion, free | Budget-limited individual developers | Weaker model capability, no advanced orchestration features |
| **Baidu Comate** | Enterprise assistant | Code completion, knowledge base integration | Internal enterprise development | Closed ecosystem, limited customization capability |
| **Claude Code** | Programmable AI tool | Native tool calling, Agent system, plugin mechanism | Complex workflows, automation, deep customization | Requires some learning cost |

## Design Philosophy

### Cost Waste for Small Requirements

In one sentence: for small requirements, just do vibe coding. There's really no need for workflow plugins.

CodeSpec essentially simulates the working mode of real development teams.

### Trust Boundary Problem

The specific manifestation is unclear about which parts of the workflow to trust AI and which parts require human intervention.

I set the boundary between **"Understanding" and "Execution"**:

- **Don't trust AI's requirement understanding**: Through requirement analysis (spec generation) and requirement clarification, let AI demonstrate its understanding of requirements, then humans intervene to review
- **Don't trust AI's design decisions**: During specific solution design, AI initiates and provides multiple options, finally humans intervene to choose or adjust
- **Trust AI execution**: When requirements are thoroughly understood and solutions are clear, AI can complete independently

This is why 4 pause points were added to a workflow that could be fully automated.

**Human oversight at subjective judgment points, hands-off at objective execution points.**

### Why Claude Code

Or rather: Why did CodeSpec choose to be a Claude Code plugin?

Claude Code is undoubtedly the best Harness in the coding field. It provides:

- Native tool calling capability
- Complete Agent system
- Flexible plugin mechanism
- Powerful context management

These capabilities enable CodeSpec to implement complex workflow orchestration and state management.

**Side note**: If you can't use Claude models, you can still use Claude Code - they're not the same thing. DeepSeek API is compatible with Anthropic's interface, meaning you can use DeepSeek V4 in Claude Code.

## Core Principles

Good tools don't let AI do everything, but let AI do what it's good at (generating code, analyzing code, providing solutions), and let humans do what humans are good at (decision-making, judgment, trade-offs).

And good workflows let you use the most suitable tools to complete the most suitable tasks. Claude Code provides stable infrastructure, CodeSpec provides structured processes. Combined, they make AI-assisted programming truly practical.
