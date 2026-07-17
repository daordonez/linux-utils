#!/usr/bin/env bash
set -euo pipefail

readonly REPOSITORY="daordonez/linux-utils"
readonly REPOSITORY_REF="${LINUX_UTILS_REF:-main}"
readonly ARCHIVE_URL="https://github.com/${REPOSITORY}/archive/${REPOSITORY_REF}.tar.gz"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TEMP_DIR=""
CONTAINERS_DIR=""
LOG_FILE=""

initialize_observability() {
    local target_home target_user target_group

    target_user="${SUDO_USER:-${USER}}"
    target_home="${HOME}"
    if [[ "${target_user}" != "root" ]] && command -v getent >/dev/null 2>&1; then
        target_home="$(getent passwd "${target_user}" | awk -F: 'NR == 1 { print $6 }')"
    fi

    [[ -n "${target_home}" ]] || target_home="${HOME}"
    CONTAINERS_DIR="${target_home}/containers"
    LOG_FILE="${CONTAINERS_DIR}/linux_utils.log"
    mkdir -p "${CONTAINERS_DIR}"
    touch "${LOG_FILE}"
    chmod 750 "${CONTAINERS_DIR}"
    chmod 640 "${LOG_FILE}"

    if [[ "$(id -u)" -eq 0 && "${target_user}" != "root" ]]; then
        target_group="$(id -gn "${target_user}")"
        chown "${target_user}:${target_group}" "${CONTAINERS_DIR}" "${LOG_FILE}"
    fi

    export LINUX_UTILS_CONTAINERS_DIR="${CONTAINERS_DIR}"
    export LINUX_UTILS_LOG_FILE="${LOG_FILE}"
    export LINUX_UTILS_TARGET_USER="${target_user}"
}

log_message() {
    local level="$1"
    shift

    printf '%s [%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "${level}" "$*" | tee -a "${LOG_FILE}"
}

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
        log_message "ERROR" "Required command not found: $1."
        exit 1
    }
}

verify_checksum() {
    local archive_file="$1"
    local actual_checksum

    [[ -n "${LINUX_UTILS_SHA256:-}" ]] || return 0

    actual_checksum="$(sha256sum "${archive_file}" | awk '{print $1}')"
    if [[ "${actual_checksum}" != "${LINUX_UTILS_SHA256}" ]]; then
        echo "Error: downloaded archive SHA-256 does not match." >&2
        log_message "ERROR" "Downloaded archive SHA-256 does not match."
        return 1
    fi
}

download_archive() {
    local archive_file="$1"
    local exit_code

    if curl --fail --location --silent --show-error \
        --retry 3 --retry-delay 2 --connect-timeout 15 --max-time 300 \
        --output "${archive_file}" "${ARCHIVE_URL}"; then
        return 0
    else
        exit_code=$?
    fi

    echo "Error: failed to download linux-utils from ${ARCHIVE_URL}." >&2
    log_message "ERROR" "Download failed for ${ARCHIVE_URL} (curl exit code: ${exit_code})."
    return "${exit_code}"
}

extract_archive() {
    local archive_file="$1"
    local destination_dir="$2"
    local exit_code

    if tar --extract --gzip --file "${archive_file}" \
        --directory "${destination_dir}" --strip-components=1; then
        return 0
    else
        exit_code=$?
    fi

    echo "Error: failed to extract the downloaded linux-utils archive." >&2
    log_message "ERROR" "Archive extraction failed (tar exit code: ${exit_code})."
    return "${exit_code}"
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

    initialize_observability
    log_message "INFO" "Linux Utils installer started."

    deploy_script="${SCRIPT_DIR}/docker/deploy_apps.sh"
    if [[ -f "${deploy_script}" ]]; then
        echo "Starting the local Docker application installer..."
        log_message "INFO" "Starting local Docker application installer."
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
    log_message "INFO" "Downloading linux-utils reference: ${REPOSITORY_REF}."
    download_archive "${archive_file}"
    verify_checksum "${archive_file}"
    extract_archive "${archive_file}" "${TEMP_DIR}"

    deploy_script="${TEMP_DIR}/docker/deploy_apps.sh"
    if [[ ! -f "${deploy_script}" ]]; then
        echo "Error: the downloaded repository does not contain docker/deploy_apps.sh." >&2
        echo "Use a branch or tag that includes the Docker application installer." >&2
        log_message "ERROR" "Downloaded repository does not contain docker/deploy_apps.sh."
        exit 1
    fi

    echo "Starting the Docker application installer..."
    log_message "INFO" "Starting downloaded Docker application installer."
    if [[ "${#deploy_args[@]}" -gt 0 ]]; then
        bash "${deploy_script}" "${deploy_args[@]}"
    else
        bash "${deploy_script}"
    fi
}

main "$@"
