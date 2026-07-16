#!/usr/bin/env bash
set -euo pipefail

readonly REPOSITORY="daordonez/linux-utils"
readonly REPOSITORY_REF="${LINUX_UTILS_REF:-main}"
readonly ARCHIVE_URL="https://github.com/${REPOSITORY}/archive/${REPOSITORY_REF}.tar.gz"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TEMP_DIR=""

cleanup() {
    [[ -n "${TEMP_DIR}" ]] && rm -rf "${TEMP_DIR}"
}

show_usage() {
    cat <<'EOF'
Usage: install.sh [--all]

Optional variables:
  LINUX_UTILS_REF       Branch or tag to download. Default: main.
  LINUX_UTILS_SHA256    Expected SHA-256 for the downloaded archive.
EOF
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Error: required command not found: $1" >&2
        exit 1
    }
}

verify_checksum() {
    local archive_file="$1"
    local actual_checksum

    [[ -n "${LINUX_UTILS_SHA256:-}" ]] || return

    actual_checksum="$(sha256sum "${archive_file}" | awk '{print $1}')"
    if [[ "${actual_checksum}" != "${LINUX_UTILS_SHA256}" ]]; then
        echo "Error: downloaded archive SHA-256 does not match." >&2
        exit 1
    fi
}

main() {
    local archive_file deploy_script
    local deploy_args=()

    case "${1:-}" in
        "")
            ;;
        --all)
            deploy_args=(--all)
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            show_usage >&2
            exit 1
            ;;
    esac

    deploy_script="${SCRIPT_DIR}/docker/deploy_apps.sh"
    if [[ -f "${deploy_script}" ]]; then
        echo "Starting the local Docker application installer..."
        if [[ "${#deploy_args[@]}" -gt 0 ]]; then
            bash "${deploy_script}" "${deploy_args[@]}"
        else
            bash "${deploy_script}"
        fi
        return
    fi

    require_command bash
    require_command curl
    require_command tar
    if [[ -n "${LINUX_UTILS_SHA256:-}" ]]; then
        require_command sha256sum
    fi

    TEMP_DIR="$(mktemp -d)"
    trap cleanup EXIT
    archive_file="${TEMP_DIR}/linux-utils.tar.gz"

    echo "Downloading linux-utils (${REPOSITORY_REF})..."
    curl --fail --location --silent --show-error --output "${archive_file}" "${ARCHIVE_URL}"
    verify_checksum "${archive_file}"
    tar --extract --gzip --file "${archive_file}" --directory "${TEMP_DIR}" --strip-components=1

    deploy_script="${TEMP_DIR}/docker/deploy_apps.sh"
    if [[ ! -f "${deploy_script}" ]]; then
        echo "Error: the downloaded repository does not contain docker/deploy_apps.sh." >&2
        echo "Use a branch or tag that includes the Docker application installer." >&2
        exit 1
    fi

    echo "Starting the Docker application installer..."
    if [[ "${#deploy_args[@]}" -gt 0 ]]; then
        bash "${deploy_script}" "${deploy_args[@]}"
    else
        bash "${deploy_script}"
    fi
}

main "$@"
