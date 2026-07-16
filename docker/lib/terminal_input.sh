#!/usr/bin/env bash

TERMINAL_INPUT="/dev/tty"

if ! (: < "${TERMINAL_INPUT}") 2>/dev/null; then
    TERMINAL_INPUT="/dev/stdin"
fi

read_masked_value() {
    local character value=""

    while IFS= read -r -s -n 1 -d '' character < "${TERMINAL_INPUT}"; do
        case "${character}" in
            $'\n'|$'\r')
                break
                ;;
            $'\b'|$'\177')
                if [[ -n "${value}" ]]; then
                    value="${value%?}"
                    printf '\b \b' >&2
                fi
                ;;
            *)
                value+="${character}"
                printf '*' >&2
                ;;
        esac
    done

    printf '\n' >&2
    REPLY="${value}"
}

read_plain_value() {
    local label="$1"

    printf '%s' "${label}" >&2
    IFS= read -r REPLY < "${TERMINAL_INPUT}"
}
