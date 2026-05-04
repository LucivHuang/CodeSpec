#!/usr/bin/env bash

set -e

JSON_MODE=false
SHORT_NAME=""
ISSUE_ID=""
BRANCH_PATTERN="feature/[feature-name]"
ARGS=()
i=1
while [ $i -le $# ]; do
    arg="${!i}"
    case "$arg" in
        --json)
            JSON_MODE=true
            ;;
        --short-name)
            if [ $((i + 1)) -gt $# ]; then
                echo 'Error: --short-name requires a value' >&2
                exit 1
            fi
            i=$((i + 1))
            next_arg="${!i}"
            # Check if the next argument is another option (starts with --)
            if [[ "$next_arg" == --* ]]; then
                echo 'Error: --short-name requires a value' >&2
                exit 1
            fi
            SHORT_NAME="$next_arg"
            ;;
        --issue-id)
            if [ $((i + 1)) -gt $# ]; then
                echo 'Error: --issue-id requires a value' >&2
                exit 1
            fi
            i=$((i + 1))
            next_arg="${!i}"
            if [[ "$next_arg" == --* ]]; then
                echo 'Error: --issue-id requires a value' >&2
                exit 1
            fi
            ISSUE_ID="$next_arg"
            ;;
        --help|-h)
            echo "Usage: $0 [--json] [--short-name <name>] [--issue-id <id>] <feature_description>"
            echo ""
            echo "Options:"
            echo "  --json              Output in JSON format"
            echo "  --short-name <name> Provide a custom short name (2-4 words) for the branch"
            echo "  --issue-id <id>     Issue/ticket ID (e.g., UG-12345)"
            echo "  --help, -h          Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 'Add user authentication system' --short-name 'user-auth'"
            echo "  $0 'Fix login bug' --issue-id UG-12345"
            exit 0
            ;;
        *)
            ARGS+=("$arg")
            ;;
    esac
    i=$((i + 1))
done

FEATURE_DESCRIPTION="${ARGS[*]}"
if [ -z "$FEATURE_DESCRIPTION" ]; then
    echo "Usage: $0 [--json] [--short-name <name>] [--issue-id <id>] <feature_description>" >&2
    exit 1
fi

# Load config from workflow.json (if available)
# zsh 兼容
if [ -n "${BASH_SOURCE+x}" ]; then SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [ -n "${ZSH_VERSION:-}" ]; then SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${(%):-%x}")" && pwd)"
else SCRIPT_DIR="$(CDPATH="" cd "$(dirname "$0")" && pwd)"; fi

# 复用 common.sh 的公共函数
source "$SCRIPT_DIR/common.sh"

_EARLY_ROOT=$(get_repo_root 2>/dev/null || echo "")

CONFIG_FILE="${_EARLY_ROOT:-.}/.codespec/config/workflow.json"

if [ -f "$CONFIG_FILE" ] && command -v jq &>/dev/null; then
    BRANCH_PATTERN=$(jq -r '.project.branchPattern // "feature/[feature-name]"' "$CONFIG_FILE" 2>/dev/null)
    SPECS_DIR_CONFIG=$(jq -r '.core.specsDir // ".codespec/specs"' "$CONFIG_FILE" 2>/dev/null)
    ISSUE_ID_PATTERN=$(jq -r '.project.issueIdPattern // ""' "$CONFIG_FILE" 2>/dev/null)
else
    BRANCH_PATTERN="feature/[feature-name]"
    SPECS_DIR_CONFIG=".codespec/specs"
    ISSUE_ID_PATTERN=""
fi

# Fallback: auto-extract issue ID from description when --issue-id was not provided
# Only attempt extraction if issueIdPattern is configured (non-empty)
if [ -z "$ISSUE_ID" ] && [ -n "$ISSUE_ID_PATTERN" ]; then
    EXTRACTED_ID=$(echo "$FEATURE_DESCRIPTION" | grep -oE "$ISSUE_ID_PATTERN" | head -1 || true)
    if [ -n "$EXTRACTED_ID" ]; then
        ISSUE_ID="$EXTRACTED_ID"
    fi
fi

# Function to clean and format a branch name
clean_branch_name() {
    local name="$1"
    echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\+/-/g' | sed 's/^-//' | sed 's/-$//'
}

# Check for non-ASCII characters in feature description
# Non-ASCII input (e.g. Chinese) would produce meaningless branch names like "---"
_check_non_ascii_input() {
    local text="$1"
    # Count non-ASCII characters
    local non_ascii_count
    non_ascii_count=$(printf '%s' "$text" | LC_ALL=C grep -c '[^ -~]' 2>/dev/null) || non_ascii_count=0
    if [[ "$non_ascii_count" -gt 0 ]]; then
        # Check if cleaning would result in empty/meaningless output
        local cleaned
        cleaned=$(echo "$text" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | sed 's/  */ /g' | sed 's/^ //;s/ $//')
        if [[ ${#cleaned} -lt 3 ]]; then
            echo "Error: Feature description contains non-ASCII characters that cannot be converted to a valid branch name." >&2
            echo "Please provide an English name using --short-name, e.g.:" >&2
            echo "  $0 '$text' --short-name 'user-auth'" >&2
            exit 1
        fi
    fi
}

# Resolve repository root. Prefer git information when available, but fall back
# to searching for repository markers so the workflow still functions in repositories that
# were initialised with --no-git.
if git rev-parse --show-toplevel >/dev/null 2>&1; then
    REPO_ROOT=$(git rev-parse --show-toplevel)
    HAS_GIT=true
else
    REPO_ROOT="$(get_repo_root)"
    if [ -z "$REPO_ROOT" ]; then
        echo "Error: Could not determine repository root. Please run this script from within the repository." >&2
        exit 1
    fi
    HAS_GIT=false
fi

cd "$REPO_ROOT"

if [[ "$SPECS_DIR_CONFIG" = /* ]]; then
    SPECS_DIR="$SPECS_DIR_CONFIG"
else
    SPECS_DIR="$REPO_ROOT/$SPECS_DIR_CONFIG"
fi
mkdir -p "$SPECS_DIR"

# Function to generate branch name with stop word filtering and length filtering
generate_branch_name() {
    local description="$1"

    # Common stop words to filter out
    local stop_words="^(i|a|an|the|to|for|of|in|on|at|by|with|from|is|are|was|were|be|been|being|have|has|had|do|does|did|will|would|should|could|can|may|might|must|shall|this|that|these|those|my|your|our|their|want|need|add|get|set)$"

    # Convert to lowercase and split into words
    local clean_name=$(echo "$description" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/ /g')

    # Filter words: remove stop words and words shorter than 3 chars (unless they're uppercase acronyms in original)
    local meaningful_words=()
    for word in $clean_name; do
        # Skip empty words
        [ -z "$word" ] && continue

        # Keep words that are NOT stop words AND (length >= 3 OR are potential acronyms)
        if ! echo "$word" | grep -qiE "$stop_words"; then
            if [ ${#word} -ge 3 ]; then
                meaningful_words+=("$word")
            elif echo "$description" | grep -q "\b${word^^}\b"; then
                # Keep short words if they appear as uppercase in original (likely acronyms)
                meaningful_words+=("$word")
            fi
        fi
    done

    # If we have meaningful words, use first 3-4 of them
    if [ ${#meaningful_words[@]} -gt 0 ]; then
        local max_words=3
        if [ ${#meaningful_words[@]} -eq 4 ]; then max_words=4; fi

        local result=""
        local count=0
        for word in "${meaningful_words[@]}"; do
            if [ $count -ge $max_words ]; then break; fi
            if [ -n "$result" ]; then result="$result-"; fi
            result="$result$word"
            count=$((count + 1))
        done
        echo "$result"
    else
        # Fallback to original logic if no meaningful words found
        local cleaned=$(clean_branch_name "$description")
        echo "$cleaned" | tr '-' '\n' | grep -v '^$' | head -3 | tr '\n' '-' | sed 's/-$//'
    fi
}

# Generate feature name
if [ -n "$SHORT_NAME" ]; then
    # Use provided short name, just clean it up
    FEATURE_NAME=$(clean_branch_name "$SHORT_NAME")
else
    # Check for non-ASCII characters before generating branch name
    _check_non_ascii_input "$FEATURE_DESCRIPTION"
    # Generate from description with smart filtering
    FEATURE_NAME=$(generate_branch_name "$FEATURE_DESCRIPTION")
fi

# Guard: prevent FEATURE_NAME from duplicating the branch pattern prefix.
# e.g. pattern "feature/[feature-name]" + name "feature-auth" → "feature/feature-auth"
# Extract all static prefixes before placeholders in BRANCH_PATTERN.
# Supports patterns like: "feature/[...]", "feat/[...]", "[feature-name]/[...]", etc.
PATTERN_PREFIXES=$(echo "$BRANCH_PATTERN" | sed -E 's/\[[^]]+\]//g' | tr '/_-' '\n' | grep -v '^$')
for prefix in $PATTERN_PREFIXES; do
    # Skip very short prefixes (1-2 chars) to avoid false positives
    if [ ${#prefix} -le 2 ]; then
        continue
    fi
    # Check if FEATURE_NAME starts with this prefix
    if [[ "$FEATURE_NAME" == "${prefix}"-* ]]; then
        FEATURE_NAME="${FEATURE_NAME#"${prefix}"-}"
        # Ensure we didn't strip everything
        if [ -z "$FEATURE_NAME" ]; then
            FEATURE_NAME=$(clean_branch_name "$SHORT_NAME$FEATURE_DESCRIPTION" | tr '-' '\n' | grep -v '^$' | head -3 | tr '\n' '-' | sed 's/-$//')
        fi
        break
    fi
done

# Build branch name by branchPattern.
# Placeholders: [feature-name], [ISSUE_ID]
if [[ "$BRANCH_PATTERN" != *"[feature-name]"* ]]; then
    echo "Error: Invalid branchPattern '$BRANCH_PATTERN'. It must include [feature-name]." >&2
    exit 1
fi

BRANCH_NAME="$BRANCH_PATTERN"
BRANCH_NAME="${BRANCH_NAME//\[feature-name\]/$FEATURE_NAME}"
BRANCH_NAME="${BRANCH_NAME//\[ISSUE_ID\]/$ISSUE_ID}"

# Clean unresolved placeholders and duplicated separators when optional segments are empty.
# Also clean dangling '_' separators (e.g. when [ISSUE_ID] is empty, '/_name' → '/name').
BRANCH_NAME=$(echo "$BRANCH_NAME" | sed -E 's@\[[^]]+\]@@g; s@//+@/@g; s@/_@/@g; s@^_@@; s@_$@@; s@^/@@; s@/$@@')

if [[ -z "$BRANCH_NAME" ]]; then
    echo "Error: Failed to render branch name from branchPattern '$BRANCH_PATTERN'." >&2
    exit 1
fi

# GitHub enforces a 244-byte limit on branch names
# Validate and truncate if necessary
MAX_BRANCH_LENGTH=244
if [ ${#BRANCH_NAME} -gt $MAX_BRANCH_LENGTH ]; then
    # Calculate base length by rendering the pattern without [feature-name]
    TEMPLATE_SANS_FEATURE="$BRANCH_PATTERN"
    TEMPLATE_SANS_FEATURE="${TEMPLATE_SANS_FEATURE//\[feature-name\]/}"
    TEMPLATE_SANS_FEATURE="${TEMPLATE_SANS_FEATURE//\[ISSUE_ID\]/$ISSUE_ID}"
    TEMPLATE_SANS_FEATURE=$(echo "$TEMPLATE_SANS_FEATURE" | sed -E 's@\[[^]]+\]@@g; s@//+@/@g; s@/_@/@g; s@_$@@; s@^/@@; s@/$@@')
    BASE_LENGTH=${#TEMPLATE_SANS_FEATURE}
    MAX_FEATURE_LENGTH=$((MAX_BRANCH_LENGTH - BASE_LENGTH))

    # Truncate feature name at word boundary to preserve semantic meaning
    TRUNCATED_FEATURE=$(echo "$FEATURE_NAME" | cut -c1-$MAX_FEATURE_LENGTH)
    # Remove trailing partial word (everything after the last hyphen within the truncated string)
    # This ensures we don't end up with "user-authentication-with-o" but rather "user-authentication-with"
    TRUNCATED_FEATURE=$(echo "$TRUNCATED_FEATURE" | sed 's/-[^-]*$//')
    # If truncation removed everything, fall back to simple truncation
    if [ -z "$TRUNCATED_FEATURE" ]; then
        TRUNCATED_FEATURE=$(echo "$FEATURE_NAME" | cut -c1-$MAX_FEATURE_LENGTH | sed 's/-$//')
    fi

    ORIGINAL_BRANCH_NAME="$BRANCH_NAME"
    # Re-render from BRANCH_PATTERN with the truncated feature name
    BRANCH_NAME="$BRANCH_PATTERN"
    BRANCH_NAME="${BRANCH_NAME//\[feature-name\]/$TRUNCATED_FEATURE}"
    BRANCH_NAME="${BRANCH_NAME//\[ISSUE_ID\]/$ISSUE_ID}"
    BRANCH_NAME=$(echo "$BRANCH_NAME" | sed -E 's@\[[^]]+\]@@g; s@//+@/@g; s@/_@/@g; s@^_@@; s@_$@@; s@^/@@; s@/$@@')

    >&2 echo "[specify] Warning: Branch name exceeded GitHub's 244-byte limit"
    >&2 echo "[specify] Original: $ORIGINAL_BRANCH_NAME (${#ORIGINAL_BRANCH_NAME} bytes)"
    >&2 echo "[specify] Truncated to: $BRANCH_NAME (${#BRANCH_NAME} bytes)"
fi

if [ "$HAS_GIT" = true ]; then
    git checkout -b "$BRANCH_NAME"
else
    >&2 echo "[specify] Warning: Git repository not detected; skipped branch creation for $BRANCH_NAME"
fi

FEATURE_DIR="$SPECS_DIR/$BRANCH_NAME"
mkdir -p "$FEATURE_DIR"

# Resolve spec template from plugin
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" && -f "$CLAUDE_PLUGIN_ROOT/templates/spec-template.md" ]]; then
    TEMPLATE="$CLAUDE_PLUGIN_ROOT/templates/spec-template.md"
else
    TEMPLATE=""
fi

SPEC_FILE="$FEATURE_DIR/spec.md"
if [[ -n "$TEMPLATE" ]]; then
    cp "$TEMPLATE" "$SPEC_FILE"
    # Prefill template metadata
    CURRENT_DATE=$(date +"%Y-%m-%d")
    sed -i.bak \
        -e "s/\[FEATURE NAME\]/$FEATURE_NAME/g" \
        -e "s|\[branch-name\]|$BRANCH_NAME|g" \
        -e "s/\[DATE\]/$CURRENT_DATE/g" \
        "$SPEC_FILE" && rm -f "${SPEC_FILE}.bak"
else
    touch "$SPEC_FILE"
fi

# Note: SPECIFY_FEATURE can still be set by the caller when multiple non-git
# feature directories exist. In the common case, later commands can now recover
# the active feature from `.workflow-state.json` or the sole feature directory.

if $JSON_MODE; then
    jq -n --arg b "$BRANCH_NAME" --arg s "$SPEC_FILE" --arg f "$FEATURE_NAME" --arg i "$ISSUE_ID" \
        '{BRANCH_NAME:$b, SPEC_FILE:$s, FEATURE_NAME:$f, ISSUE_ID:$i, SPECIFY_FEATURE:$b}'
else
    echo "BRANCH_NAME: $BRANCH_NAME"
    echo "SPEC_FILE: $SPEC_FILE"
    echo "FEATURE_NAME: $FEATURE_NAME"
    if [ -n "$ISSUE_ID" ]; then
        echo "ISSUE_ID: $ISSUE_ID"
    fi
    echo "SPECIFY_FEATURE: $BRANCH_NAME"
    echo "# To use in non-git environments, run: export SPECIFY_FEATURE='$BRANCH_NAME'"
fi
