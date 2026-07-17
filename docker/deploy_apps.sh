#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly APPS_DIR="${SCRIPT_DIR}/apps"

source "${SCRIPT_DIR}/lib/terminal_input.sh"
source "${SCRIPT_DIR}/lib/logging.sh"
source "${SCRIPT_DIR}/lib/compose.sh"

COMPOSE_COMMAND=()
APPS=()

require_compose() {
    if docker compose version >/dev/null 2>&1; then
        COMPOSE_COMMAND=(docker compose)
    elif docker-compose version >/dev/null 2>&1; then
        COMPOSE_COMMAND=(docker-compose)
    else
        echo "Error: Docker Compose is not installed or is not accessible by the current user." >&2
        log_error "Docker Compose is not installed or is not accessible by the current user."
        exit 1
    fi
}

discover_apps() {
    local app_dir

    while IFS= read -r -d '' app_dir; do
        if [[ -f "${app_dir}/compose.yaml" || -f "${app_dir}/compose.yml" || \
            -f "${app_dir}/docker-compose.yaml" || -f "${app_dir}/docker-compose.yml" ]]; then
            APPS+=("$(basename "${app_dir}")")
        fi
    done < <(find "${APPS_DIR}" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
}

prompt_required_value() {
    local label="$1"
    local secret="$2"
    local value

    while true; do
        if [[ "${secret}" == "true" ]]; then
            printf '%s: ' "${label}" >&2
            read_masked_value
            value="${REPLY}"
        else
            read_plain_value "${label}: "
            value="${REPLY}"
        fi

        if [[ -n "${value}" ]]; then
            printf '%s' "${value}"
            return
        fi

        echo "The value cannot be empty." >&2
    done
}

prepare_ddns() {
    local app_dir="$1"
    local env_file="${app_dir}/.env"
    local api_token domains

    rm -f "${env_file}"
    touch "${env_file}"
    chmod 600 "${env_file}"

    echo "DDNS setup: paste the Cloudflare API token now; each character will appear as an asterisk." >&2
    api_token="$(prompt_required_value "Enter CLOUDFLARE_API_TOKEN" true)"
    upsert_env_value "${env_file}" "CLOUDFLARE_API_TOKEN" "${api_token}"

    domains="$(prompt_required_value "Enter comma-separated FQDNs (for example, home.example.com)" false)"
    upsert_env_value "${env_file}" "DOMAINS" "${domains}"
    upsert_env_value "${env_file}" "PROXIED" "false"
    upsert_env_value "${env_file}" "IP6_PROVIDER" "none"
}

find_compose_file() {
    local app_dir="$1"
    local compose_file

    for compose_file in compose.yaml compose.yml docker-compose.yaml docker-compose.yml; do
        if [[ -f "${app_dir}/${compose_file}" ]]; then
            printf '%s\n' "${app_dir}/${compose_file}"
            return
        fi
    done

    return 1
}

stage_service_definition() {
    local app="$1"
    local app_dir="$2"
    local service_dir="${CONTAINERS_DIR}/${app}"
    local compose_source compose_destination env_source env_destination

    compose_source="$(find_compose_file "${app_dir}")"
    compose_destination="${service_dir}/$(basename "${compose_source}")"
    cp "${compose_source}" "${compose_destination}"
    set_service_file_permissions "${compose_destination}" 640

    env_source="${app_dir}/.env"
    env_destination="${service_dir}/.env"
    if [[ -f "${env_source}" ]]; then
        cp "${env_source}" "${env_destination}"
        set_service_file_permissions "${env_destination}" 600
    fi
}

sanitize_service_environment() {
    local app="$1"
    local env_file="${CONTAINERS_DIR}/${app}/.env"

    [[ -f "${env_file}" ]] || return 0
    sanitize_env_file "${env_file}" "${env_file}"
}

deploy_app() {
    local app="$1"
    local app_dir="${APPS_DIR}/${app}"
    local service_dir="${CONTAINERS_DIR}/${app}"
    local launcher="${app_dir}/run_${app}.sh"
    local deployment_status=0

    echo
    echo "Deploying: ${app}"
    prepare_service_directory "${app}"

    if [[ "${app}" == "ddns" ]]; then
        echo "Resetting the existing DDNS container and configuration."
        remove_container_if_exists "ddns-service"
        prepare_ddns "${app_dir}"
    fi

    stage_service_definition "${app}" "${app_dir}"

    if [[ -f "${launcher}" ]]; then
        (
            cd "${service_dir}"
            export LINUX_UTILS_SERVICE_DIR="${service_dir}"
            bash "${launcher}"
        ) || deployment_status=$?
    else
        (
            cd "${service_dir}"
            if [[ "${app}" != "ddns" ]]; then
                echo "Resetting the existing stack, including containers, networks, and volumes."
            fi
            reset_compose_stack "${COMPOSE_COMMAND[@]}"
        ) || deployment_status=$?
    fi

    sanitize_service_environment "${app}"
    (( deployment_status == 0 )) || return "${deployment_status}"
    log_info "Deployment completed for service: ${app}"
}

show_menu() {
    local index

    echo "Available Docker applications:"
    for index in "${!APPS[@]}"; do
        printf '  %d) %s\n' "$((index + 1))" "${APPS[index]}"
    done
    echo "  A) Install all"
    echo "  0) Exit without installing"
}

main() {
    local selection index app

    [[ -d "${APPS_DIR}" ]] || {
        echo "Error: applications directory does not exist: ${APPS_DIR}" >&2
        log_error "Applications directory does not exist: ${APPS_DIR}"
        exit 1
    }

    initialize_observability
    require_compose
    discover_apps

    if [[ "${#APPS[@]}" -eq 0 ]]; then
        echo "No Docker Compose applications were found in ${APPS_DIR}."
        log_warn "No Docker Compose applications were found in ${APPS_DIR}."
        exit 0
    fi

    case "${1:-}" in
        "")
            show_menu
            read_plain_value "Select an option: "
            selection="${REPLY}"
            ;;
        --all)
            selection="A"
            ;;
        --help|-h)
            echo "Usage: $(basename "$0") [--all]"
            exit 0
            ;;
        *)
            echo "Usage: $(basename "$0") [--all]" >&2
            exit 1
            ;;
    esac

    case "${selection}" in
        0)
            echo "No applications were installed."
            ;;
        [Aa])
            for app in "${APPS[@]}"; do
                deploy_app "${app}"
            done
            ;;
        *)
            if [[ "${selection}" =~ ^[0-9]+$ ]] && \
                (( selection >= 1 && selection <= ${#APPS[@]} )); then
                index=$((selection - 1))
                deploy_app "${APPS[index]}"
            else
                echo "Invalid option." >&2
                exit 1
            fi
            ;;
    esac

    log_info "Docker application installer completed successfully."
}

main "$@"
