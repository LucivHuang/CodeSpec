#!/usr/bin/env bash

# codespec Gate Check — 阶段门禁验证脚本
# 程序化验证产物结构和内容质量，AI 无法绕过
#
# 用法:
#   ./gate-check.sh <gate_name> <feature_dir> [--json]
#
# 门禁类型:
#   specify-done     验证 spec.md 完整性（进入 stage2 前）
#   clarify-done     验证 spec.md 完整性 + 需求锚点存在（进入 stage3 前）
#   plan-done        验证 plan.md + code-exploration.md 完整性（进入 stage4 前）
#   tasks-done       验证 tasks.md 完整性（进入 stage5 前）
#   implement-done   验证 tasks.md 完整性 + 完成率（进入 stage6 前）
#   review-done      验证 review-report.md 存在（进入扩展阶段前）
#   spec             单独验证 spec.md
#
# 输出:
#   JSON 模式: {"gate":"...","passed":true/false,"errors":[],"warnings":[]}
#   文本模式: PASSED / FAILED + 错误列表

# ================================
# 加载公共函数
# ================================

# zsh 兼容
if [ -n "${BASH_SOURCE+x}" ]; then _SELF_SCRIPT="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then _SELF_SCRIPT="${(%):-%x}"
else _SELF_SCRIPT="$0"; fi
_SELF_DIR="$(CDPATH="" cd "$(dirname "$_SELF_SCRIPT")" && pwd)"

source "$_SELF_DIR/common.sh"

# ================================
# 参数解析
# ================================

GATE_NAME="${1:-}"
FEATURE_DIR="${2:-}"
JSON_MODE=false

for arg in "$@"; do
    [[ "$arg" == "--json" ]] && JSON_MODE=true
done

if [[ -z "$GATE_NAME" ]] || [[ -z "$FEATURE_DIR" ]]; then
    echo "ERROR: Usage: gate-check.sh <gate_name> <feature_dir> [--json]" >&2
    echo "  gate_name: specify-done | clarify-done | plan-done | tasks-done | implement-done | review-done | spec" >&2
    exit 1
fi

if [[ ! -d "$FEATURE_DIR" ]]; then
    echo "ERROR: Feature directory not found: $FEATURE_DIR" >&2
    exit 1
fi

# ================================
# 工具函数
# ================================

ERRORS=()
WARNINGS=()

add_error() {
    ERRORS+=("$1")
}

add_warning() {
    WARNINGS+=("$1")
}

# 检查文件是否存在
require_file() {
    local file="$1"
    local label="$2"
    if [[ ! -f "$file" ]]; then
        add_error "必需文件缺失: $label ($file)"
        return 1
    fi
    return 0
}

# 检查文件是否有实质内容（按词数统计，避免结构化标题/分隔线为主的文档被误拒）
require_non_empty() {
    local file="$1"
    local label="$2"
    local min_words="${3:-50}"
    local content_lines
    local word_count
    local char_count
    local min_chars=$((min_words * 4))

    content_lines=$(grep -vE '^$|^#+\s|^---' "$file" 2>/dev/null || true)
    word_count=$(printf '%s\n' "$content_lines" | wc -w | tr -d ' ') || word_count=0
    char_count=$(printf '%s\n' "$content_lines" | tr -d '[:space:]' | wc -m | tr -d ' ') || char_count=0

    if [[ "$word_count" -lt "$min_words" && "$char_count" -lt "$min_chars" ]]; then
        add_error "$label 内容不足: 仅 $word_count 个有效词 / $char_count 个有效字符（最少需要 $min_words 个词或 $min_chars 个字符）"
        return 1
    fi
    return 0
}

# 检查残留占位符（大小写不敏感，避免变体占位符漏检）
# allow_needs_clarification=true 时，允许保留有限数量的 [NEEDS CLARIFICATION]
check_no_placeholders() {
    local file="$1"
    local label="$2"
    local allow_needs_clarification="${3:-false}"
    local max_needs_clarification="${4:-0}"
    local placeholder_count
    local nc_count

    placeholder_count=$(grep -ciE '\[(todo|tbd|placeholder|action required)\]' "$file" 2>/dev/null) || placeholder_count=0

    if [[ "$placeholder_count" -gt 0 ]]; then
        add_error "$label 存在 $placeholder_count 个未解决的占位符 ([TODO]/[TBD]/[ACTION REQUIRED])"
        # 列出具体位置
        local details
        details=$(grep -niE '\[(todo|tbd|placeholder|action required)\]' "$file" 2>/dev/null | head -5)
        add_error "  占位符位置: $details"
        return 1
    fi

    nc_count=$(grep -ciE '\[needs clarification\]' "$file" 2>/dev/null) || nc_count=0
    if [[ "$allow_needs_clarification" == "true" ]]; then
        if [[ "$nc_count" -gt "$max_needs_clarification" ]]; then
            add_error "$label 存在 $nc_count 个 [NEEDS CLARIFICATION]，超过允许上限 $max_needs_clarification"
            return 1
        fi
    elif [[ "$nc_count" -gt 0 ]]; then
        add_error "$label 存在 $nc_count 个未解决的占位符 ([NEEDS CLARIFICATION])"
        local nc_details
        nc_details=$(grep -niE '\[needs clarification\]' "$file" 2>/dev/null | head -5)
        add_error "  占位符位置: $nc_details"
        return 1
    fi
    return 0
}

# ================================
# 门禁: spec.md
# ================================

gate_check_spec() {
    local allow_needs_clarification="${1:-false}"
    local spec_file="$FEATURE_DIR/spec.md"
    require_file "$spec_file" "spec.md" || return 0
    require_non_empty "$spec_file" "spec.md" 50
    if [[ "$allow_needs_clarification" == "true" ]]; then
        check_no_placeholders "$spec_file" "spec.md" "true" 5
    else
        check_no_placeholders "$spec_file" "spec.md"
    fi
}

# ================================
# 门禁: plan.md
# ================================

gate_check_plan() {
    local plan_file="$FEATURE_DIR/plan.md"
    require_file "$plan_file" "plan.md" || return 0
    require_non_empty "$plan_file" "plan.md" 50
    check_no_placeholders "$plan_file" "plan.md"
}

# ================================
# 门禁: code-exploration.md
# ================================

gate_check_code_exploration() {
    local ce_file="$FEATURE_DIR/code-exploration.md"
    if [[ ! -f "$ce_file" ]]; then
        add_error "code-exploration.md 缺失：plan 阶段必须产出代码探索报告"
        return 0
    fi
    require_non_empty "$ce_file" "code-exploration.md" 80
}

# ================================
# 门禁: tasks.md
# ================================

# gate_check_tasks 接受可选参数 caller，用于区分调用场景
# 用法: gate_check_tasks [caller]
#   caller="implement-done" 时跳过初始状态检查（implement 后 [x] 是预期状态）
gate_check_tasks() {
    local caller="${1:-}"
    local tasks_file="$FEATURE_DIR/tasks.md"
    require_file "$tasks_file" "tasks.md" || return 0

    local task_info total completed
    task_info=$(count_tasks "$tasks_file")
    total=$(echo "$task_info" | cut -d' ' -f1)
    completed=$(echo "$task_info" | cut -d' ' -f2)

    if [[ "$total" -lt 1 ]]; then
        add_error "tasks.md 没有任务项（未找到 - [ ] 格式的任务）"
    fi

    # 检查任务初始状态：新生成的 tasks.md 不应包含已标记完成的任务
    # 防止 AI agent 错误生成预标记 [x] 的任务导致 implement 阶段跳过它们
    # 但在 implement-done 门禁中，[x] 是预期状态，跳过此检查
    if [[ "$caller" != "implement-done" ]] && [[ "$completed" -gt 0 ]] && [[ "$total" -gt 0 ]]; then
        add_warning "tasks.md 包含 $completed 个已标记 [x] 的任务，新生成的任务应全为 [ ] 状态"
    fi

    check_no_placeholders "$tasks_file" "tasks.md"
}

# ================================
# 门禁: tasks.md 完成率（仅 implement-done 使用）
# ================================

gate_check_tasks_completion() {
    local tasks_file="$FEATURE_DIR/tasks.md"
    local label="tasks.md 完成率"

    require_file "$tasks_file" "$label" || return 0

    local task_info total completed
    task_info=$(count_tasks "$tasks_file")
    total=$(echo "$task_info" | cut -d' ' -f1)
    completed=$(echo "$task_info" | cut -d' ' -f2)

    if [[ "$total" -gt 0 ]]; then
        local pct=$((completed * 100 / total))
        if [[ "$completed" -lt "$total" ]]; then
            add_error "$label: $completed/$total 已完成 ($pct%)，需要 100% 完成才能通过门禁"
        fi
    fi
}

# ================================
# 门禁: 需求锚点
# ================================

gate_check_anchors() {
    local spec_file="$FEATURE_DIR/spec.md"
    if [[ ! -f "$spec_file" ]]; then
        return 0
    fi

    # 检查是否存在需求锚点章节
    if ! grep -qE '^##\s+需求锚点' "$spec_file" 2>/dev/null; then
        add_error "spec.md 缺少需求锚点章节（未找到 '## 需求锚点' 标题）"
        return 0
    fi

    # 提取需求锚点章节内容（从 ## 需求锚点 到下一个 ## 或文件末尾）
    local anchor_section
    anchor_section=$(awk '/^##\s+需求锚点/,/^##\s+[^#]/ {print}' "$spec_file" | sed '$d' 2>/dev/null)

    # 在锚点章节中统计 RQ-* 数量
    local anchor_count
    anchor_count=$(echo "$anchor_section" | grep -cE 'RQ-[0-9]+' 2>/dev/null) || anchor_count=0

    if [[ "$anchor_count" -lt 1 ]]; then
        add_error "需求锚点章节中缺少需求条目（未找到 RQ-* 格式的需求）"
        return 0
    fi

    # 校验格式一致性：强制统一格式（推荐 RQ-001 带前导零）
    # 提取所有锚点并按数字值分组，检查是否存在数字值相同但格式不同的锚点
    local anchor_list
    anchor_list=$(echo "$anchor_section" | grep -oE 'RQ-[0-9]+' 2>/dev/null | sort -u)

    # 检查格式混用：同时存在 RQ-001 和 RQ-1 这样的格式
    local has_padded has_unpadded
    has_padded=$(echo "$anchor_list" | grep -cE '^RQ-0[0-9]+$' 2>/dev/null) || has_padded=0
    has_unpadded=$(echo "$anchor_list" | grep -cE '^RQ-[1-9][0-9]*$' 2>/dev/null) || has_unpadded=0

    if [[ "$has_padded" -gt 0 ]] && [[ "$has_unpadded" -gt 0 ]]; then
        add_error "需求锚点格式不一致：同时存在前导零（如 RQ-001）和无前导零（如 RQ-1）的锚点，必须统一格式"
        return 0
    fi

    # 检查数字值冲突：RQ-1 和 RQ-001 数字值相同但格式不同
    # 将所有锚点转换为数字值，检查是否有重复
    local numeric_values
    numeric_values=$(echo "$anchor_list" | sed -E 's/RQ-0*([0-9]+)/\1/' | sort -n)
    local dup_numeric_count
    dup_numeric_count=$(echo "$numeric_values" | uniq -d | wc -l | tr -d ' ') || dup_numeric_count=0

    if [[ "$dup_numeric_count" -gt 0 ]]; then
        local dup_nums
        dup_nums=$(echo "$numeric_values" | uniq -d | head -5 | tr '\n' ', ' | sed 's/,$//')
        add_error "需求锚点存在数字值冲突：数字 $dup_nums 对应多个不同格式的锚点（如 RQ-1 和 RQ-001）"
        return 0
    fi

    # 校验唯一性：检查重复的锚点 ID
    local dup_count
    dup_count=$(echo "$anchor_section" | grep -oE 'RQ-[0-9]+' 2>/dev/null | sort | uniq -d | wc -l | tr -d ' ') || dup_count=0
    if [[ "$dup_count" -gt 0 ]]; then
        local dups
        dups=$(echo "$anchor_section" | grep -oE 'RQ-[0-9]+' 2>/dev/null | sort | uniq -d | head -5 | tr '\n' ', ' | sed 's/,$//')
        add_error "需求锚点章节中存在重复的 ID: $dups"
    fi

    # 警告：检查锚点是否散落在其他章节（锚点章节外的 RQ-*）
    local total_anchors_in_file
    total_anchors_in_file=$(grep -cE 'RQ-[0-9]+' "$spec_file" 2>/dev/null) || total_anchors_in_file=0
    if [[ "$total_anchors_in_file" -gt "$anchor_count" ]]; then
        local outside_count=$((total_anchors_in_file - anchor_count))
        add_warning "发现 $outside_count 个 RQ-* 锚点散落在需求锚点章节之外，建议集中管理"
    fi
}

# ================================
# 组合门禁
# ================================

gate_specify_done() {
    gate_check_spec "true"
}

gate_clarify_done() {
    gate_check_spec
    gate_check_anchors
}

gate_plan_done() {
    gate_check_spec
    gate_check_anchors
    gate_check_plan
    gate_check_code_exploration
}

gate_tasks_done() {
    gate_check_spec
    gate_check_anchors
    gate_check_plan
    gate_check_tasks
}

gate_implement_done() {
    gate_check_spec
    gate_check_anchors
    gate_check_plan
    gate_check_tasks "implement-done"
    gate_check_tasks_completion
}

gate_review_done() {
    gate_implement_done
    local report_file="$FEATURE_DIR/review-report.md"
    require_file "$report_file" "review-report.md" || return 0
    require_non_empty "$report_file" "review-report.md" 80
}

# ================================
# 路由与输出
# ================================

case "$GATE_NAME" in
    specify-done)
        gate_specify_done
        ;;
    clarify-done)
        gate_clarify_done
        ;;
    plan-done)
        gate_plan_done
        ;;
    tasks-done)
        gate_tasks_done
        ;;
    implement-done)
        gate_implement_done
        ;;
    review-done)
        gate_review_done
        ;;
    spec)
        gate_check_spec
        ;;
    *)
        echo "ERROR: Unknown gate: $GATE_NAME" >&2
        echo "  Valid gates: specify-done | clarify-done | plan-done | tasks-done | implement-done | review-done | spec" >&2
        exit 1
        ;;
esac

# 输出结果
error_count=${#ERRORS[@]}
warning_count=${#WARNINGS[@]}
passed=$([[ "$error_count" -eq 0 ]] && echo "true" || echo "false")

if $JSON_MODE; then
    # JSON 输出
    errors_json="[]"
    warnings_json="[]"

    if [[ "$error_count" -gt 0 ]]; then
        errors_json=$(printf '%s\n' "${ERRORS[@]}" | jq -R . | jq -s .)
    fi
    if [[ "$warning_count" -gt 0 ]]; then
        warnings_json=$(printf '%s\n' "${WARNINGS[@]}" | jq -R . | jq -s .)
    fi

    jq -n \
        --arg gate "$GATE_NAME" \
        --argjson passed "$passed" \
        --argjson errors "$errors_json" \
        --argjson warnings "$warnings_json" \
        '{gate: $gate, passed: $passed, errors: $errors, warnings: $warnings}'
else
    # 文本输出
    if [[ "$passed" == "true" ]]; then
        echo "✅ GATE PASSED: $GATE_NAME"
    else
        echo "❌ GATE FAILED: $GATE_NAME"
        echo ""
        echo "错误 ($error_count):"
        for err in "${ERRORS[@]}"; do
            echo "  ✗ $err"
        done
    fi

    if [[ "$warning_count" -gt 0 ]]; then
        echo ""
        echo "警告 ($warning_count):"
        for warn in "${WARNINGS[@]}"; do
            echo "  ⚠ $warn"
        done
    fi
fi

# 退出码：0=通过, 1=失败
[[ "$passed" == "true" ]] && exit 0 || exit 1
