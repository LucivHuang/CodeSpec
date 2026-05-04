#!/usr/bin/env bash

# Consolidated prerequisite checking script
#
# This script provides unified prerequisite checking for Spec-Driven Development workflow.
# It replaces the functionality previously spread across multiple scripts.
#
# Usage: ./check-prerequisites.sh [OPTIONS]
#
# OPTIONS:
#   --json              Output in JSON format
#   --require-tasks     Require tasks.md to exist (for implementation phase)
#   --include-tasks     Include tasks.md in AVAILABLE_DOCS list
#   --setup-plan        Setup plan template (create dirs, copy template)
#   --paths-only        Only output path variables (no validation)
#   --help, -h          Show help message
#
# OUTPUTS:
#   JSON mode: {"FEATURE_DIR":"...", "AVAILABLE_DOCS":["..."]}
#   Text mode: FEATURE_DIR:... \n AVAILABLE_DOCS: \n ✓/✗ file.md
#   Paths only: REPO_ROOT: ... \n BRANCH: ... \n FEATURE_DIR: ... etc.

set -e

# Parse command line arguments
JSON_MODE=false
REQUIRE_TASKS=false
INCLUDE_TASKS=false
PATHS_ONLY=false
SETUP_PLAN=false

for arg in "$@"; do
    case "$arg" in
        --json)
            JSON_MODE=true
            ;;
        --require-tasks)
            REQUIRE_TASKS=true
            ;;
        --include-tasks)
            INCLUDE_TASKS=true
            ;;
        --paths-only)
            PATHS_ONLY=true
            ;;
        --setup-plan)
            SETUP_PLAN=true
            ;;
        --help|-h)
            cat << 'EOF'
Usage: check-prerequisites.sh [OPTIONS]

Consolidated prerequisite checking for Spec-Driven Development workflow.

OPTIONS:
  --json              Output in JSON format
  --require-tasks     Require tasks.md to exist (for implementation phase)
  --include-tasks     Include tasks.md in AVAILABLE_DOCS list
  --setup-plan        Setup plan template (create dirs, copy template)
  --paths-only        Only output path variables (no prerequisite validation)
  --help, -h          Show this help message

EXAMPLES:
  # Check task prerequisites (plan.md required)
  ./check-prerequisites.sh --json

  # Check implementation prerequisites (plan.md + tasks.md required)
  ./check-prerequisites.sh --json --require-tasks --include-tasks

  # Get feature paths only (no validation)
  ./check-prerequisites.sh --paths-only

EOF
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option '$arg'. Use --help for usage information." >&2
            exit 1
            ;;
    esac
done

# Source common functions
# zsh 兼容
if [ -n "${BASH_SOURCE+x}" ]; then SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [ -n "${ZSH_VERSION:-}" ]; then SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${(%):-%x}")" && pwd)"
else SCRIPT_DIR="$(CDPATH="" cd "$(dirname "$0")" && pwd)"; fi
source "$SCRIPT_DIR/common.sh"

# Get feature paths and validate branch
eval $(get_feature_paths)
check_feature_branch "$CURRENT_BRANCH" "$HAS_GIT" || exit 1

# Setup plan template if requested
if $SETUP_PLAN; then
    mkdir -p "$FEATURE_DIR"
    if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" && -f "$CLAUDE_PLUGIN_ROOT/templates/plan-template.md" ]]; then
        cp "$CLAUDE_PLUGIN_ROOT/templates/plan-template.md" "$IMPL_PLAN"
        CURRENT_DATE=$(date +"%Y-%m-%d")
        sed -i.bak \
            -e "s|\\[FEATURE\\]|$CURRENT_BRANCH|g" \
            -e "s|\\[branch-name\\]|$CURRENT_BRANCH|g" \
            -e "s/\\[DATE\\]/$CURRENT_DATE/g" \
            "$IMPL_PLAN" && rm -f "${IMPL_PLAN}.bak"
    else
        echo "Warning: Plan template not found" >&2
        touch "$IMPL_PLAN"
    fi
fi

# If paths-only mode, output paths and exit (support JSON + paths-only combined)
if $PATHS_ONLY; then
    if $JSON_MODE; then
        # Minimal JSON paths payload (no validation performed)
        printf '{"REPO_ROOT":"%s","BRANCH":"%s","FEATURE_DIR":"%s","FEATURE_SPEC":"%s","IMPL_PLAN":"%s","TASKS":"%s"}\n' \
            "$REPO_ROOT" "$CURRENT_BRANCH" "$FEATURE_DIR" "$FEATURE_SPEC" "$IMPL_PLAN" "$TASKS"
    else
        echo "REPO_ROOT: $REPO_ROOT"
        echo "BRANCH: $CURRENT_BRANCH"
        echo "FEATURE_DIR: $FEATURE_DIR"
        echo "FEATURE_SPEC: $FEATURE_SPEC"
        echo "IMPL_PLAN: $IMPL_PLAN"
        echo "TASKS: $TASKS"
    fi
    exit 0
fi

# Validate feature directory exists (required for all modes)
if [[ ! -d "$FEATURE_DIR" ]]; then
    echo "ERROR: Feature directory not found: $FEATURE_DIR" >&2
    echo "Run /codespec:specify first to create the feature structure." >&2
    exit 1
fi

if $REQUIRE_TASKS && [[ ! -f "$TASKS" ]]; then
    echo "ERROR: Required file not found: $TASKS" >&2
    echo "Run /codespec:tasks first to generate the task list." >&2
    exit 1
fi

# Build list of available documents using common.sh helper
INCLUDE_FLAG=""
$INCLUDE_TASKS && INCLUDE_FLAG="--include-tasks"
AVAILABLE_DOCS=$(list_available_docs "$FEATURE_DIR" "$INCLUDE_FLAG")

# Output results
if $JSON_MODE; then
    # Build JSON array of documents
    if [[ -z "$AVAILABLE_DOCS" ]]; then
        json_docs="[]"
    else
        json_docs=$(echo "$AVAILABLE_DOCS" | tr ' ' '\n' | jq -R . | jq -s .)
    fi

    if $SETUP_PLAN; then
        printf '{"FEATURE_SPEC":"%s","IMPL_PLAN":"%s","FEATURE_DIR":"%s","BRANCH":"%s","HAS_GIT":"%s","AVAILABLE_DOCS":%s}\n' \
            "$FEATURE_SPEC" "$IMPL_PLAN" "$FEATURE_DIR" "$CURRENT_BRANCH" "$HAS_GIT" "$json_docs"
    else
        printf '{"FEATURE_DIR":"%s","AVAILABLE_DOCS":%s}\n' "$FEATURE_DIR" "$json_docs"
    fi
else
    # Text output
    echo "FEATURE_DIR:$FEATURE_DIR"
    echo "AVAILABLE_DOCS:"

    check_file "$RESEARCH" "research.md"
    check_file "$DATA_MODEL" "data-model.md"
    check_dir "$CONTRACTS_DIR" "contracts/"
    check_file "$QUICKSTART" "quickstart.md"

    if $INCLUDE_TASKS; then
        check_file "$TASKS" "tasks.md"
    fi
fi
