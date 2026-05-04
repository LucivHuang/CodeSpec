#!/usr/bin/env bash

# codespec Workflow Initialization
# 合并环境检查、配置解析、状态检测和记忆文件校验
#
# 用法: bash workflow-init.sh --json
# 输出: 结构化 key=value 对，供 workflow.md 编排器使用

set -e

# zsh 兼容
if [ -n "${BASH_SOURCE+x}" ]; then _WI_SELF="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then _WI_SELF="${(%):-%x}"
else _WI_SELF="$0"; fi
_WI_DIR="$(CDPATH="" cd "$(dirname "$_WI_SELF")" && pwd)"

source "$_WI_DIR/common.sh"
source "$_WI_DIR/workflow-state.sh"

REPO_ROOT="$(get_repo_root)"
cd "$REPO_ROOT"

# ================================
# 1. 环境检查
# ================================  
ENV_CHECK=$(bash "$_WI_DIR/check-env.sh" --json) || true
if [ "$(echo "$ENV_CHECK" | jq -r '.passed')" != "true" ]; then
  echo "ENV_CHECK_FAILED=true"
  echo "$ENV_CHECK"
  exit 1
fi

# ================================
# 2. 配置解析
# ================================
CONFIG_FILE="$REPO_ROOT/.codespec/config/workflow.json"
if [ -f "$CONFIG_FILE" ]; then
  SPECS_DIR=$(jq -r '.core.specsDir // ".codespec/specs"' "$CONFIG_FILE")
  OUTPUT_LANGUAGE=$(jq -r '.core.language // "zh-CN"' "$CONFIG_FILE")
  PROJECT_ISSUE_PATTERN=$(jq -r '.project.issueIdPattern // ""' "$CONFIG_FILE")
  ENABLED_EXTENSIONS=$(jq -c '[.extensions.stages // [] | .[] | select(.enabled == true)]' "$CONFIG_FILE")
else
  SPECS_DIR=".codespec/specs"
  OUTPUT_LANGUAGE="zh-CN"
  PROJECT_ISSUE_PATTERN=""
  ENABLED_EXTENSIONS="[]"
fi

# ================================
# 3. 状态检测（中断恢复）
# ================================
if workflow_state_detect; then
  STATE_FILE=$(get_state_file_path)
  if [[ -z "$STATE_FILE" || ! -f "$STATE_FILE" ]]; then
    echo "RESUME_DETECTED=false"
    echo "Warning: State detection succeeded but state file not accessible" >&2
  else
    echo "RESUME_DETECTED=true"
    workflow_state_show "$STATE_FILE"
    jq -r '"RESUME_STAGE=\(.currentStage)\nRESUME_ISSUE_ID=\(.issueId)\nRESUME_BRANCH=\(.branch)"' "$STATE_FILE"
    for stage in stage1-specify stage2-clarify stage3-plan stage4-tasks stage5-implement stage6-review; do
      STATUS=$(jq -r ".stages.\"$stage\".status" "$STATE_FILE")
      echo "STATUS_${stage}=${STATUS}"
      [ "$STATUS" = "completed" ] && echo "OUTPUTS_${stage}=$(jq -c ".stages.\"$stage\".outputs" "$STATE_FILE")"
    done
  fi
else
  echo "RESUME_DETECTED=false"
fi

# ================================
# 4. 记忆文件检查
# ================================
MISSING=""
[ ! -f "$REPO_ROOT/.codespec/memory/constitution.md" ] && MISSING="$MISSING constitution.md"
[ ! -f "$REPO_ROOT/.codespec/memory/project-context.json" ] && MISSING="$MISSING project-context.json"
echo "MISSING_MEMORY_FILES=$MISSING"

# ================================
# 4.1 清理孤立的备份文件
# ================================
# memory-writer.sh 写入时创建 .backup 文件，正常完成后删除
# 如果进程在中间被杀死，.backup 文件会残留
ORPHAN_BACKUPS=$(find "$REPO_ROOT/.codespec/memory" -name '*.backup' 2>/dev/null | wc -l | tr -d ' ')
if [ "$ORPHAN_BACKUPS" -gt 0 ]; then
    echo "ORPHAN_BACKUP_CLEANUP=$ORPHAN_BACKUPS"
    find "$REPO_ROOT/.codespec/memory" -name '*.backup' -delete 2>/dev/null || true
fi
# 同时清理状态文件的临时文件和残留锁目录
if [[ "$SPECS_DIR" = /* ]]; then
    CLEANUP_SPECS_DIR="$SPECS_DIR"
else
    CLEANUP_SPECS_DIR="$REPO_ROOT/$SPECS_DIR"
fi
find "$CLEANUP_SPECS_DIR" -name '*.tmp' 2>/dev/null | while read -r f; do
    rm -f "$f" 2>/dev/null
done
find "$CLEANUP_SPECS_DIR" -name '*.lockdir' -type d 2>/dev/null | while read -r d; do
    rmdir "$d" 2>/dev/null || true
done

# ================================
# 5. 输出汇总
# ================================
echo "PLUGIN_ROOT=$(cd "$_WI_DIR/../.." && pwd)"
echo "CONFIG_SPECS_DIR=$SPECS_DIR"
echo "CONFIG_LANGUAGE=$OUTPUT_LANGUAGE"
echo "CONFIG_ISSUE_PATTERN=$PROJECT_ISSUE_PATTERN"
echo "ENABLED_EXTENSIONS=$ENABLED_EXTENSIONS"
