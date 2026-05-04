#!/usr/bin/env bash

# codespec environment check
# Validates runtime dependencies required by workflow scripts.

set -e

JSON_MODE=false
for arg in "$@"; do
    case "$arg" in
        --json)
            JSON_MODE=true
            ;;
        --help|-h)
            cat << 'EOF'
Usage: check-env.sh [--json]

Checks required binaries for codespec:
  - bash (required)
  - jq   (required)
  - git  (optional)
EOF
            exit 0
            ;;
    esac
done

errors=()
warnings=()

check_cmd() {
    local cmd="$1"
    if command -v "$cmd" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

if ! check_cmd bash; then
    errors+=("Missing required binary: bash")
fi

if ! check_cmd jq; then
    errors+=("Missing required binary: jq")
fi

if ! check_cmd git; then
    warnings+=("Optional binary not found: git (non-git mode supported with reduced capability)")
fi

passed=true
if [[ "${#errors[@]}" -gt 0 ]]; then
    passed=false
fi

if $JSON_MODE; then
    errors_json="[]"
    warnings_json="[]"

    if [[ "${#errors[@]}" -gt 0 ]]; then
        errors_json=$(printf '%s\n' "${errors[@]}" | jq -R . | jq -s .)
    fi

    if [[ "${#warnings[@]}" -gt 0 ]]; then
        warnings_json=$(printf '%s\n' "${warnings[@]}" | jq -R . | jq -s .)
    fi

    jq -n \
        --argjson passed "$passed" \
        --argjson errors "$errors_json" \
        --argjson warnings "$warnings_json" \
        '{passed: $passed, errors: $errors, warnings: $warnings}'
else
    if [[ "$passed" == "true" ]]; then
        echo "codespec environment check passed"
    else
        echo "codespec environment check failed"
    fi

    if [[ "${#errors[@]}" -gt 0 ]]; then
        echo ""
        echo "Errors:"
        for err in "${errors[@]}"; do
            echo "  - $err"
        done
    fi

    if [[ "${#warnings[@]}" -gt 0 ]]; then
        echo ""
        echo "Warnings:"
        for warn in "${warnings[@]}"; do
            echo "  - $warn"
        done
    fi
fi

if [[ "$passed" == "true" ]]; then
    exit 0
fi
exit 1
