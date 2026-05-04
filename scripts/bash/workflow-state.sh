#!/bin/bash

# codespec Workflow State Management (Simplified)
# 工作流状态文件管理脚本（简化版）
# 兼容 bash 和 zsh（macOS 默认 shell）
#
# 用法:
#   source .codespec/scripts/bash/workflow-state.sh

# zsh 兼容
if [ -n "${BASH_SOURCE+x}" ]; then _SELF_SCRIPT="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then _SELF_SCRIPT="${(%):-%x}"
else _SELF_SCRIPT="$0"; fi

# 仅在直接执行时启用 set -e，避免 source 时影响调用方 shell
if [ -n "${BASH_SOURCE+x}" ]; then
  [[ "${BASH_SOURCE[0]}" == "${0}" ]] && set -e
elif [ -n "${ZSH_VERSION:-}" ]; then
  [[ ! "$ZSH_EVAL_CONTEXT" == *":file"* ]] && set -e
else
  set -e
fi

# ================================
# 配置
# ================================

# 复用 common.sh 的公共函数
source "$(cd "$(dirname "$_SELF_SCRIPT")" && pwd)/common.sh"

STATE_FILE_NAME=".workflow-state.json"
STATE_VERSION="2.0"

# ================================
# 工具函数
# ================================

# 获取当前功能目录
_ws_get_feature_dir() {
    local repo_root branch feature_dir
    repo_root="$(get_repo_root)"
    branch="$(get_current_branch)"
    feature_dir="$(get_feature_dir "$repo_root" "$branch")"
    if [[ -d "$feature_dir" ]]; then
        echo "$feature_dir"
        return 0
    fi
    echo ""
    return 1
}

# 获取当前分支对应的状态文件（严格匹配，不做全局回退）
# 避免在分支 A 上误读分支 B 的状态文件
_ws_get_state_file_for_current_branch() {
    local feature_dir
    feature_dir="$(_ws_get_feature_dir 2>/dev/null)"

    if [[ -n "$feature_dir" ]] && [[ -d "$feature_dir" ]] && [[ -f "$feature_dir/$STATE_FILE_NAME" ]]; then
        echo "$feature_dir/$STATE_FILE_NAME"
        return 0
    fi

    echo ""
    return 1
}

# 获取状态文件路径
# 严格按当前分支匹配，不做跨分支回退
get_state_file_path() {
    local feature_dir="${1:-$(_ws_get_feature_dir 2>/dev/null)}"

    if [[ -n "$feature_dir" ]] && [[ -d "$feature_dir" ]]; then
        echo "$feature_dir/$STATE_FILE_NAME"
        return 0
    fi

    echo ""
    return 1
}

# 获取当前时间（ISO 8601 格式）
get_current_time() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# ================================
# 原子写入（文件锁）
# ================================

# 带文件锁的状态文件写入
# 用法: _ws_locked_write <state_file> <jq_filter> [jq_args...]
# 使用 mkdir 作为跨平台原子锁（POSIX 保证原子性，macOS/Linux 均可用）
_ws_locked_write() {
    local state_file="$1"
    shift
    local temp_file="${state_file}.tmp"
    local lock_dir="${state_file}.lockdir"
    local lock_pid_file="${lock_dir}/pid"
    local waited=0

    # mkdir 在所有 POSIX 系统上是原子操作，无需 flock
    while ! mkdir "$lock_dir" 2>/dev/null; do
        # 检测残留锁：读取锁目录中的 PID，检查进程是否仍在运行
        if [[ -d "$lock_dir" ]]; then
            local lock_pid=""
            if [[ -f "$lock_pid_file" ]]; then
                lock_pid=$(cat "$lock_pid_file" 2>/dev/null || echo "")
            fi

            # 如果有 PID 且进程已死，清理残留锁
            if [[ -n "$lock_pid" ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
                echo "Warning: Stale lock detected (PID $lock_pid not running), removing $lock_dir" >&2
                rm -rf "$lock_dir" 2>/dev/null || true
                continue
            fi

            # 如果没有 PID 文件，回退到时间检测（兼容旧版本）
            if [[ -z "$lock_pid" ]]; then
                local lock_age=0
                if stat -f %m "$lock_dir" >/dev/null 2>&1; then
                    # macOS stat
                    lock_age=$(( $(date +%s) - $(stat -f %m "$lock_dir") ))
                elif stat -c %Y "$lock_dir" >/dev/null 2>&1; then
                    # Linux stat
                    lock_age=$(( $(date +%s) - $(stat -c %Y "$lock_dir") ))
                fi
                if [ "$lock_age" -gt 60 ]; then
                    echo "Warning: Stale lock detected (${lock_age}s old, no PID), force removing $lock_dir" >&2
                    rm -rf "$lock_dir" 2>/dev/null || true
                    continue
                fi
            fi
        fi

        waited=$((waited + 1))
        if [ "$waited" -ge 10 ]; then
            echo "Error: Failed to acquire lock on $lock_dir after 10s" >&2
            return 1
        fi
        sleep 1
    done

    # 写入当前进程 PID 到锁目录
    echo $$ > "$lock_pid_file" 2>/dev/null || true

    local ret=0
    if ! jq "$@" "$state_file" > "$temp_file"; then
        echo "Error: Failed to update state file" >&2
        rm -f "$temp_file"
        ret=1
    elif ! jq empty "$temp_file" 2>/dev/null; then
        echo "Error: Temp file contains invalid JSON, aborting" >&2
        rm -f "$temp_file"
        ret=1
    elif ! mv "$temp_file" "$state_file"; then
        echo "Error: Failed to replace state file" >&2
        rm -f "$temp_file"
        ret=1
    fi

    rm -rf "$lock_dir" 2>/dev/null || true
    return $ret
}

# ================================
# 核心函数
# ================================

# 创建工作流状态文件
# 用法: workflow_state_create [issue_id] <branch> [feature_dir]
workflow_state_create() {
    local issue_id="$1"
    local branch="$2"
    local feature_dir="${3:-}"

    if [[ -z "$branch" ]]; then
        echo "Error: branch is required" >&2
        return 1
    fi

    if [[ -n "$feature_dir" ]] && [[ ! -d "$feature_dir" ]]; then
        echo "Error: feature directory does not exist: $feature_dir" >&2
        return 1
    fi

    if [[ -z "$feature_dir" ]] && [[ -n "$branch" ]]; then
        local specs_dir
        specs_dir="$(get_specs_dir "$(get_repo_root)")"
        if [[ -d "$specs_dir/$branch" ]]; then
            feature_dir="$specs_dir/$branch"
        fi
    fi

    if [[ -z "$feature_dir" ]]; then
        feature_dir=$(_ws_get_feature_dir)
    fi

    if [[ -z "$feature_dir" ]]; then
        echo "Error: Cannot determine feature directory" >&2
        return 1
    fi

    local state_file=$(get_state_file_path "$feature_dir")
    local current_time=$(get_current_time)

    # 创建状态文件
    cat > "$state_file" <<EOF
{
  "version": "$STATE_VERSION",
  "issueId": "$issue_id",
  "branch": "$branch",
  "featureDir": "$feature_dir",
  "startTime": "$current_time",
  "lastUpdateTime": "$current_time",
  "currentStage": "stage0-init",
  "stages": {
    "stage1-specify": {
      "status": "pending"
    },
    "stage2-clarify": {
      "status": "pending"
    },
    "stage3-plan": {
      "status": "pending"
    },
    "stage4-tasks": {
      "status": "pending"
    },
    "stage5-implement": {
      "status": "pending"
    },
    "stage6-review": {
      "status": "pending"
    }
  },
  "repos": {},
  "interrupted": false
}
EOF

    echo "$state_file"
}

# 更新工作流状态
# 用法: workflow_state_update <stage> <status> [outputs_json]
workflow_state_update() {
    local stage="$1"
    local status="$2"
    local outputs_json="${3:-{}}"

    if [[ -z "$stage" ]] || [[ -z "$status" ]]; then
        echo "Error: stage and status are required" >&2
        return 1
    fi

    local state_file=$(get_state_file_path)
    if [[ -z "$state_file" ]] || [[ ! -f "$state_file" ]]; then
        echo "Error: State file not found" >&2
        return 1
    fi

    # 注意: 门禁检查由 workflow.md / 各子命令在进入阶段前显式调用 gate-check.sh
    # 此处不再自动执行，避免双重门禁

    local current_time=$(get_current_time)

    # 使用带文件锁的原子写入
    _ws_locked_write "$state_file" \
       --arg stage "$stage" \
       --arg status "$status" \
       --arg time "$current_time" \
       --argjson outputs "$outputs_json" \
       '
       .lastUpdateTime = $time |
       .currentStage = $stage |
       .stages[$stage].status = $status |
       if ($outputs | length > 0) then
           .stages[$stage].outputs = $outputs
       else . end
       '
}

# 标记工作流中断
# 用法: workflow_state_mark_interruption <reason>
workflow_state_mark_interruption() {
    local reason="$1"

    if [[ -z "$reason" ]]; then
        echo "Error: reason is required" >&2
        return 1
    fi

    local state_file=$(get_state_file_path)
    if [[ -z "$state_file" ]] || [[ ! -f "$state_file" ]]; then
        echo "Error: State file not found" >&2
        return 1
    fi

    local temp_file="${state_file}.tmp"

    # 获取当前阶段的恢复建议
    # currentStage 记录的是正在执行/未完成的阶段，恢复时应从该阶段本身继续
    local current_stage=$(jq -r '.currentStage' "$state_file")
    local resume_cmd=""

    case "$current_stage" in
        "stage0-init"|"stage1-specify")
            resume_cmd="/codespec:specify"
            ;;
        "stage2-clarify")
            resume_cmd="/codespec:clarify"
            ;;
        "stage3-plan")
            resume_cmd="/codespec:plan"
            ;;
        "stage4-tasks")
            resume_cmd="/codespec:tasks"
            ;;
        "stage5-implement")
            resume_cmd="/codespec:implement"
            ;;
        "stage6-review")
            resume_cmd="/codespec:review"
            ;;
        ext-*)
            resume_cmd="/codespec:workflow (resume extensions)"
            ;;
    esac

    # 使用带文件锁的原子写入
    _ws_locked_write "$state_file" \
       --argjson interrupted true \
       --arg reason "$reason" \
       --arg resumeCmd "$resume_cmd" \
       --arg time "$(get_current_time)" \
       '
       .interrupted = $interrupted |
       .lastUpdateTime = $time |
       .interruptionReason = $reason |
       .resumeCommand = $resumeCmd
       '

    echo ""
    echo "⚠️ 工作流已中断"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "原因: $reason"
    echo "状态文件: $state_file"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "恢复建议:"
    echo "  $resume_cmd            # 继续执行"
    echo ""
}

# 检测可恢复的工作流
# 用法: workflow_state_detect
workflow_state_detect() {
    local state_file=$(_ws_get_state_file_for_current_branch)

    if [[ -z "$state_file" ]]; then
        return 1
    fi

    # 检查是否有中断标记
    local interrupted=$(jq -r '.interrupted' "$state_file")
    if [[ "$interrupted" == "true" ]]; then
        return 0
    fi

    # 检查是否有未完成的阶段（in_progress 或部分完成）
    local has_in_progress=$(jq -r '.stages | to_entries | map(select(.value.status == "in_progress")) | length > 0' "$state_file")
    if [[ "$has_in_progress" == "true" ]]; then
        return 0
    fi

    # 检查是否存在部分完成的工作流：至少一个阶段 completed 且至少一个阶段 pending
    local has_completed=$(jq -r '.stages | to_entries | map(select(.value.status == "completed")) | length > 0' "$state_file")
    local has_pending=$(jq -r '.stages | to_entries | map(select(.value.status == "pending")) | length > 0' "$state_file")
    if [[ "$has_completed" == "true" ]] && [[ "$has_pending" == "true" ]]; then
        return 0
    fi

    return 1
}

# 显示工作流状态
# 用法: workflow_state_show [state_file]
workflow_state_show() {
    local state_file="${1:-$(get_state_file_path)}"

    if [[ -z "$state_file" ]] || [[ ! -f "$state_file" ]]; then
        echo "❌ 未找到工作流状态文件"
        return 1
    fi

    echo ""
    echo "🔄 工作流状态"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # 基本信息
    local issue_id=$(jq -r '.issueId' "$state_file")
    local branch=$(jq -r '.branch' "$state_file")
    local current_stage=$(jq -r '.currentStage' "$state_file")

    echo "工单: $issue_id"
    echo "分支: $branch"
    echo "当前阶段: $current_stage"

    # 阶段进度
    echo ""
    echo "阶段进度:"
    jq -r '.stages | to_entries | .[] | "  \(.key): \(.value.status)"' "$state_file"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# 清理工作流状态文件
# 用法: workflow_state_cleanup [feature_dir]
workflow_state_cleanup() {
    local state_file=$(get_state_file_path "${1:-}")

    if [[ -z "$state_file" ]] || [[ ! -f "$state_file" ]]; then
        return 0
    fi

    rm "$state_file"
    echo "✅ 状态文件已删除"
}

# ================================
# CLI 入口（可选）
# ================================

# 当脚本直接执行时提供 CLI 接口
# 检测是否被 source 还是直接执行
_ws_is_directly_executed() {
  if [ -n "${BASH_SOURCE+x}" ]; then
    [[ "${BASH_SOURCE[0]}" == "${0}" ]]
  elif [ -n "${ZSH_VERSION:-}" ]; then
    # zsh: ZSH_EVAL_CONTEXT 包含 ":file" 表示被 source（函数内可能是 cmdarg:file:shfunc）
    [[ ! "$ZSH_EVAL_CONTEXT" == *":file"* ]]
  else
    return 0
  fi
}

if _ws_is_directly_executed; then
    cmd="${1:-}"
    shift || true

    case "$cmd" in
        create)
            workflow_state_create "$@"
            ;;
        update)
            workflow_state_update "$@"
            ;;
        interrupt)
            workflow_state_mark_interruption "$@"
            ;;
        detect)
            workflow_state_detect && echo "检测到未完成的工作流" || echo "无未完成的工作流"
            ;;
        show)
            workflow_state_show "$@"
            ;;
        cleanup)
            workflow_state_cleanup
            ;;
        *)
            echo "Usage: $0 {create|update|interrupt|detect|show|cleanup} [args...]"
            echo ""
            echo "Commands:"
            echo "  create [issue_id] <branch>          - 创建状态文件（issue_id 可为空）"
            echo "  update <stage> <status> [outputs]   - 更新状态"
            echo "  interrupt <reason>                   - 标记中断"
            echo "  detect                               - 检测未完成工作流"
            echo "  show                                 - 显示状态"
            echo "  cleanup                              - 清理状态文件"
            exit 1
            ;;
    esac
fi
