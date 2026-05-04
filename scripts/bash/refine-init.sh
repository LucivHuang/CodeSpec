#!/usr/bin/env bash

# codespec Refine Initialization
# 合并环境检查、产物目录发现、工作流状态检测
#
# 用法: bash refine-init.sh
# 输出: 结构化 key=value 对，供 refine.md 使用

set -e

# zsh 兼容
if [ -n "${BASH_SOURCE+x}" ]; then _RI_SELF="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then _RI_SELF="${(%):-%x}"
else _RI_SELF="$0"; fi
_RI_DIR="$(CDPATH="" cd "$(dirname "$_RI_SELF")" && pwd)"

source "$_RI_DIR/common.sh"
source "$_RI_DIR/workflow-state.sh"

REPO_ROOT="$(get_repo_root)"
BRANCH="$(get_current_branch)"
FEATURE_DIR="$(get_feature_dir "$REPO_ROOT" "$BRANCH")"
MEMORY_DIR="$REPO_ROOT/.codespec/memory"

# 工作流状态检查
ACTIVE_WORKFLOW=false
STATE_FILE="$(get_state_file_path "$FEATURE_DIR" 2>/dev/null || echo "")"
[[ -n "$STATE_FILE" && -f "$STATE_FILE" ]] && ACTIVE_WORKFLOW=true

# 发现已有产物
ARTIFACTS=""
for f in spec.md plan.md tasks.md research.md data-model.md quickstart.md; do
  [[ -f "$FEATURE_DIR/$f" ]] && ARTIFACTS="$ARTIFACTS $f"
done

# 输出
echo "PLUGIN_ROOT=$_RI_DIR/../.."
echo "BRANCH=$BRANCH"
echo "FEATURE_DIR=$FEATURE_DIR"
echo "MEMORY_DIR=$MEMORY_DIR"
echo "ACTIVE_WORKFLOW=$ACTIVE_WORKFLOW"
echo "ARTIFACTS=$ARTIFACTS"
[[ ! -d "$FEATURE_DIR" ]] && echo "ERROR: Feature directory not found: $FEATURE_DIR"
