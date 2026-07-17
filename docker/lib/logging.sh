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

set_service_file_permissions() {
    local file_path="$1"
    local mode="$2"
    local target_user="${LINUX_UTILS_TARGET_USER:-}"
    local target_group

    chmod "${mode}" "${file_path}"
    if [[ "$(id -u)" -eq 0 && -n "${target_user}" && "${target_user}" != "root" ]]; then
        target_group="$(id -gn "${target_user}")"
        chown "${target_user}:${target_group}" "${file_path}"
    fi
}

upsert_env_value() {
    local env_file="$1"
    local key="$2"
    local value="$3"
    local temp_file

    touch "${env_file}"
    temp_file="$(mktemp "${env_file}.XXXXXX")"
    awk -F= -v key="${key}" '$1 != key { print }' "${env_file}" > "${temp_file}"
    printf '%s=%s\n' "${key}" "${value}" >> "${temp_file}"
    mv "${temp_file}" "${env_file}"
    set_service_file_permissions "${env_file}" 600
}

sanitize_env_file() {
    local source_file="$1"
    local destination_file="$2"
    local temp_file

    temp_file="$(mktemp "${destination_file}.XXXXXX")"
    awk '
        /^[[:space:]]*($|#)/ { print; next }
        /^[A-Za-z_][A-Za-z0-9_]*=/ {
            key = $0
            sub(/=.*/, "", key)
            if (toupper(key) ~ /(TOKEN|KEY|SECRET|PASSWORD|PASS|CREDENTIAL)/) {
                print key "="
            } else {
                print
            }
            next
        }
        { print }
    ' "${source_file}" > "${temp_file}"
    mv "${temp_file}" "${destination_file}"
    set_service_file_permissions "${destination_file}" 600
}
