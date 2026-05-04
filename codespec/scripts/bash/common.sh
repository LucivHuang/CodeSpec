#!/usr/bin/env bash
# Common functions and variables for all scripts
# 兼容 bash 和 zsh（macOS 默认 shell）

# 解析当前脚本路径（bash/zsh 兼容）
if [ -n "${BASH_SOURCE+x}" ]; then _COMMON_SCRIPT="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then _COMMON_SCRIPT="${(%):-%x}"
else _COMMON_SCRIPT="$0"; fi

# ================================
# 插件根目录解析
# ================================

# 解析并设置 CLAUDE_PLUGIN_ROOT 环境变量
# 用法: resolve_plugin_root
# 返回: 成功返回 0，失败返回 1
resolve_plugin_root() {
    if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" && -d "$CLAUDE_PLUGIN_ROOT/scripts/bash" ]]; then
        return 0
    fi

    for candidate in "$PWD" "$(dirname "$PWD")"; do
        if [[ -f "$candidate/.claude-plugin/plugin.json" && -d "$candidate/scripts/bash" && -d "$candidate/commands" && -d "$candidate/shared" ]]; then
            export CLAUDE_PLUGIN_ROOT="$candidate"
            return 0
        fi
    done

    echo "ERROR: CLAUDE_PLUGIN_ROOT is not set or points to an invalid plugin root" >&2
    echo "  Searched: $PWD, $(dirname "$PWD")" >&2
    return 1
}

# ================================
# 仓库根目录解析
# ================================

# Get repository root, with fallback for non-git repositories
get_repo_root() {
    if git rev-parse --show-toplevel >/dev/null 2>&1; then
        git rev-parse --show-toplevel
    else
        # Fall back: search upward for a directory containing .codespec/
        local dir="$PWD"
        while [ "$dir" != "/" ]; do
            if [ -d "$dir/.codespec" ]; then
                echo "$dir"
                return 0
            fi
            dir="$(dirname "$dir")"
        done
        # Last resort: use current working directory
        echo "$PWD"
    fi
}

get_workflow_config_file() {
    local repo_root="$1"
    echo "$repo_root/.codespec/config/workflow.json"
}

get_workflow_value() {
    local repo_root="$1"
    local jq_expr="$2"
    local default_value="$3"
    local config_file
    config_file="$(get_workflow_config_file "$repo_root")"

    if [[ -f "$config_file" ]] && command -v jq >/dev/null 2>&1; then
        jq -r "$jq_expr // \"$default_value\"" "$config_file" 2>/dev/null || echo "$default_value"
    else
        echo "$default_value"
    fi
}

to_abs_path() {
    local repo_root="$1"
    local path_value="$2"

    if [[ "$path_value" = /* ]]; then
        echo "$path_value"
    else
        echo "$repo_root/$path_value"
    fi
}

get_specs_dir() {
    local repo_root="$1"
    local specs_dir_rel
    specs_dir_rel="$(get_workflow_value "$repo_root" '.core.specsDir' '.codespec/specs')"
    to_abs_path "$repo_root" "$specs_dir_rel"
}

get_branch_pattern() {
    local repo_root="$1"
    get_workflow_value "$repo_root" '.project.branchPattern' 'feature/[feature-name]'
}

branch_pattern_to_regex() {
    local branch_pattern="$1"
    local escaped

    escaped="$(printf '%s' "$branch_pattern" | sed -E 's/[][(){}.+*?^$|\\]/\\&/g')"

    # [ISSUE_ID]_ with trailing underscore → optional group (must be checked before standalone)
    escaped="${escaped//\[ISSUE_ID\]_/([^/_]+_)?}"
    # _[feature-name] → required (underscore consumed by ISSUE_ID group above)
    escaped="${escaped//_\[feature-name\]/[^/]+}"
    # /[feature-name] → required segment
    escaped="${escaped//\/\[feature-name\]/\/[^/]+}"
    # standalone [feature-name]
    escaped="${escaped//\[feature-name\]/[^/]+}"
    # /[ISSUE_ID] → optional segment (old pattern compat)
    escaped="${escaped//\/\[ISSUE_ID\]/(\/[^/]+)?}"
    escaped="${escaped//\[ISSUE_ID\]/[^/]+}"

    printf '^%s$' "$escaped"
}

# Get current branch, with fallback for non-git repositories
get_current_branch() {
    local repo_root
    local specs_dir
    local active_feature

    # First check if SPECIFY_FEATURE environment variable is set
    if [[ -n "${SPECIFY_FEATURE:-}" ]]; then
        echo "$SPECIFY_FEATURE"
        return
    fi

    # Then check git if available
    if git rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
        git rev-parse --abbrev-ref HEAD
        return
    fi

    repo_root="$(get_repo_root)"
    specs_dir="$(get_specs_dir "$repo_root")"

    if [[ -d "$specs_dir" ]]; then
        # Prefer an active workflow state file when present.
        local state_candidates=()
        local active_states=()
        while IFS= read -r state_file; do
            [[ -n "$state_file" ]] && state_candidates+=("$state_file")
        done < <(find "$specs_dir" -name '.workflow-state.json' 2>/dev/null)

        if [[ "${#state_candidates[@]}" -gt 0 ]]; then
            local state_file
            for state_file in "${state_candidates[@]}"; do
                if jq -e '
                    .interrupted == true
                    or (.stages | to_entries | any(.value.status == "in_progress" or .value.status == "pending"))
                  ' "$state_file" >/dev/null 2>&1; then
                    active_states+=("$state_file")
                fi
            done

            if [[ "${#active_states[@]}" -eq 1 ]]; then
                active_feature="$(dirname "${active_states[0]}")"
                active_feature="${active_feature#"$specs_dir"/}"
                echo "$active_feature"
                return
            fi
        fi

        # Fall back to a single feature directory when there is no ambiguity.
        local spec_matches=()
        while IFS= read -r spec_file; do
            [[ -n "$spec_file" ]] && spec_matches+=("$spec_file")
        done < <(find "$specs_dir" -mindepth 2 -maxdepth 6 -name 'spec.md' 2>/dev/null)

        if [[ "${#spec_matches[@]}" -eq 1 ]]; then
            active_feature="$(dirname "${spec_matches[0]}")"
            active_feature="${active_feature#"$specs_dir"/}"
            echo "$active_feature"
            return
        fi
    fi

    # For non-git repos, SPECIFY_FEATURE is still the safest override when
    # there are multiple candidate feature directories.
    echo "Error: Non-git environment detected and SPECIFY_FEATURE is not set." >&2
    echo "Please set SPECIFY_FEATURE to the target branch/feature name, e.g.:" >&2
    echo "  export SPECIFY_FEATURE='feature/my-feature'" >&2
    return 1
}

# Check if we have git available
has_git() {
    git rev-parse --show-toplevel >/dev/null 2>&1
}

check_feature_branch() {
    local branch="$1"
    local has_git_repo="$2"

    # For non-git repos, we can't enforce branch naming but still provide output
    if [[ "$has_git_repo" != "true" ]]; then
        echo "[specify] Warning: Git repository not detected; skipped branch validation" >&2
        return 0
    fi

    local repo_root
    local branch_pattern
    local branch_regex
    repo_root=$(get_repo_root)
    branch_pattern="$(get_branch_pattern "$repo_root")"
    branch_regex="$(branch_pattern_to_regex "$branch_pattern")"

    # Branch naming rule is config-driven by workflow.json project.branchPattern.
    if [[ ! "$branch" =~ $branch_regex ]]; then
        echo "ERROR: Not on a valid feature/bugfix/hotfix branch. Current branch: $branch" >&2
        echo "Branch naming convention (from workflow.json):" >&2
        echo "  $branch_pattern" >&2
        return 1
    fi

    return 0
}

get_feature_dir() {
    local repo_root="$1"
    local branch_name="$2"
    local specs_dir

    specs_dir="$(get_specs_dir "$repo_root")"
    echo "$specs_dir/$branch_name"
}

get_feature_paths() {
    local repo_root=$(get_repo_root)
    local current_branch=$(get_current_branch)
    local has_git_repo="false"

    if has_git; then
        has_git_repo="true"
    fi

    local feature_dir=$(get_feature_dir "$repo_root" "$current_branch")

    cat <<EOF
REPO_ROOT='$repo_root'
CURRENT_BRANCH='$current_branch'
HAS_GIT='$has_git_repo'
FEATURE_DIR='$feature_dir'
FEATURE_SPEC='$feature_dir/spec.md'
IMPL_PLAN='$feature_dir/plan.md'
TASKS='$feature_dir/tasks.md'
RESEARCH='$feature_dir/research.md'
DATA_MODEL='$feature_dir/data-model.md'
QUICKSTART='$feature_dir/quickstart.md'
CONTRACTS_DIR='$feature_dir/contracts'
EOF
}

check_file() { [[ -f "$1" ]] && echo "  ✓ $2" || echo "  ✗ $2"; }
check_dir() { [[ -d "$1" && -n $(ls -A "$1" 2>/dev/null) ]] && echo "  ✓ $2" || echo "  ✗ $2"; }

# 统计 tasks.md 中的任务数和完成数
# 用法: count_tasks <tasks_file>
# 输出: "total completed" (两个数字，空格分隔)
count_tasks() {
    local file="$1"
    local total completed
    total=$(grep -cE '^\s*- \[(x| )\]' "$file" 2>/dev/null) || total=0
    completed=$(grep -cE '^\s*- \[x\]' "$file" 2>/dev/null) || completed=0
    echo "$total $completed"
}

# List available design documents in a feature directory
# Usage: list_available_docs <feature_dir> [--include-tasks]
# Output: space-separated list of available document names
list_available_docs() {
    local feature_dir="$1"
    local include_tasks="${2:-}"
    local docs=()

    [[ -f "$feature_dir/research.md" ]] && docs+=("research.md")
    [[ -f "$feature_dir/data-model.md" ]] && docs+=("data-model.md")
    [[ -d "$feature_dir/contracts" && -n "$(ls -A "$feature_dir/contracts" 2>/dev/null)" ]] && docs+=("contracts/")
    [[ -f "$feature_dir/quickstart.md" ]] && docs+=("quickstart.md")
    [[ "$include_tasks" == "--include-tasks" && -f "$feature_dir/tasks.md" ]] && docs+=("tasks.md")

    echo "${docs[*]}"
}

