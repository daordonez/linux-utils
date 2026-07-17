#!/usr/bin/env bash

readonly CONTAINERS_DIR="${LINUX_UTILS_CONTAINERS_DIR:-${HOME}/containers}"
readonly LOG_FILE="${LINUX_UTILS_LOG_FILE:-${CONTAINERS_DIR}/linux_utils.log}"

initialize_observability() {
    mkdir -p "${CONTAINERS_DIR}"
    touch "${LOG_FILE}"
    chmod 750 "${CONTAINERS_DIR}"
    chmod 640 "${LOG_FILE}"
}

log_message() {
    local level="$1"
    shift

    printf '%s [%s] %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "${level}" "$*" | tee -a "${LOG_FILE}"
}

log_info() {
    log_message "INFO" "$*"
}

log_warn() {
    log_message "WARN" "$*"
}

log_error() {
    log_message "ERROR" "$*" >&2
}

prepare_service_directory() {
    local service_name="$1"
    local service_dir="${CONTAINERS_DIR}/${service_name}"
    local target_user="${LINUX_UTILS_TARGET_USER:-}"
    local target_group

    mkdir -p "${service_dir}"
    chmod 750 "${service_dir}"
    if [[ "$(id -u)" -eq 0 && -n "${target_user}" && "${target_user}" != "root" ]]; then
        target_group="$(id -gn "${target_user}")"
        chown "${target_user}:${target_group}" "${service_dir}"
    fi
    log_info "Service directory ready: ${service_dir}"
}
