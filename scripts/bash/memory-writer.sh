#!/usr/bin/env bash

###############################################################################
# codespec Memory Writer (简化版 - 自适应记忆)
#
# 设计原则：
# - LLM 自主决定记录什么、如何分类
# - 脚本只提供基础的追加能力
# - 容错：写入失败不影响主流程
#
# 用法：
#   source memory-writer.sh
#   memory_append "workflow-history" "完成了用户认证功能，选择了最小改动方案，审查评分 4.5"
#   memory_append "code-patterns" "发现高质量的 React Hook 模式：useAuth"
###############################################################################

# 复用 common.sh 的公共函数
if [ -n "${BASH_SOURCE+x}" ]; then _MW_SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [ -n "${ZSH_VERSION:-}" ]; then _MW_SCRIPT_DIR="$(CDPATH="" cd "$(dirname "${(%):-%x}")" && pwd)"
else _MW_SCRIPT_DIR="$(CDPATH="" cd "$(dirname "$0")" && pwd)"; fi
source "$_MW_SCRIPT_DIR/common.sh"

REPO_ROOT="$(get_repo_root)"
MEMORY_DIR="$REPO_ROOT/.codespec/memory"
MEMORY_LOG_FILE="$REPO_ROOT/.codespec/logs/memory-errors.log"

mkdir -p "$MEMORY_DIR"
mkdir -p "$(dirname "$MEMORY_LOG_FILE")"

get_timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

log_memory_error() {
    local operation="$1"
    local error_msg="$2"
    echo "[$(get_timestamp)] $operation: $error_msg" >> "$MEMORY_LOG_FILE"
}

###############################################################################
# 核心函数：追加式记忆
###############################################################################

# 追加记忆条目到指定类别
# 用法: memory_append <category> <content>
# 示例: memory_append "workflow-history" "完成用户认证功能，评分 4.5"
memory_append() {
  local category="$1"
  local content="$2"

  if [[ -z "$category" || -z "$content" ]]; then
    echo "⚠️  Skipping memory append (empty category or content)" >&2
    return 0
  fi

  local file="$MEMORY_DIR/${category}.md"
  local ts; ts=$(get_timestamp)
  local branch; branch=$(get_current_branch)

  echo "📝 Recording to memory/$category.md..." >&2

  # 追加模式：时间戳 + 分支 + 内容
  {
    echo ""
    echo "---"
    echo "**Date**: $ts | **Branch**: $branch"
    echo ""
    echo "$content"
  } >> "$file"

  if [[ $? -eq 0 ]]; then
    echo "✅ Memory recorded to $category" >&2
  else
    echo "⚠️  Failed to record memory (non-fatal)" >&2
    log_memory_error "memory_append" "Failed to write to $category.md"
    return 1
  fi
}

###############################################################################
# 兼容层：保留旧函数签名，内部调用 memory_append
###############################################################################

memory_record_workflow() {
  local issue_id="${1:-unknown}"
  local review_score="${2:-0}"
  local selected_solution="${3:-unknown}"
  local spec_path="${4:-}"

  local content="工作流完成：工单 $issue_id，方案 $selected_solution，审查评分 $review_score"
  [[ -n "$spec_path" ]] && content="$content，规格文件 $spec_path"

  memory_append "workflow-history" "$content"
}

memory_record_solution_preference() {
  local solution="$1"
  local context="${2:-general}"

  memory_append "user-preferences" "选择方案：$solution（上下文：$context）"
}

memory_record_code_pattern() {
  local pattern_type="${1:-unknown}"
  local pattern_name="${2:-unknown}"
  local review_score="${3:-0}"
  local file_path="${4:-}"
  local libraries="${5:-}"

  # 只记录高质量模式（评分 >= 4.5）
  if awk -v score="$review_score" 'BEGIN{exit !(score < 4.5)}'; then
    echo "⏭️  Skipping pattern record (score < 4.5)" >&2
    return 0
  fi

  local content="代码模式：$pattern_name（类型：$pattern_type，评分：$review_score）"
  [[ -n "$file_path" ]] && content="$content，位于 $file_path"
  [[ -n "$libraries" ]] && content="$content，使用库：$libraries"

  memory_append "code-patterns" "$content"
}

memory_record_refinement() {
  local refine_type="${1:-unknown}"
  local description="${2:-}"
  local reasoning="${3:-}"

  [[ -z "$description" ]] && return 0

  local content="微调反馈（$refine_type）：$description"
  [[ -n "$reasoning" ]] && content="$content。原因：$reasoning"

  memory_append "refinements" "$content"
}
