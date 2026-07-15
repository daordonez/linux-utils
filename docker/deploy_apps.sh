#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly APPS_DIR="${SCRIPT_DIR}/apps"

COMPOSE_COMMAND=()
APPS=()

require_compose() {
    if docker compose version >/dev/null 2>&1; then
        COMPOSE_COMMAND=(docker compose)
    elif docker-compose version >/dev/null 2>&1; then
        COMPOSE_COMMAND=(docker-compose)
    else
        echo "Error: Docker Compose no está instalado o no es accesible para el usuario actual." >&2
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

read_env_value() {
    local env_file="$1"
    local key="$2"

    awk -F= -v key="${key}" '$1 == key { value = substr($0, length(key) + 2) } END { print value }' "${env_file}"
}

upsert_env_value() {
    local env_file="$1"
    local key="$2"
    local value="$3"
    local temp_file

    temp_file="$(mktemp "${env_file}.XXXXXX")"
    awk -F= -v key="${key}" '$1 != key { print }' "${env_file}" > "${temp_file}"
    printf '%s=%s\n' "${key}" "${value}" >> "${temp_file}"
    chmod 600 "${temp_file}"
    mv "${temp_file}" "${env_file}"
}

prompt_required_value() {
    local label="$1"
    local secret="$2"
    local value

    while true; do
        if [[ "${secret}" == "true" ]]; then
            read -r -s -p "${label}: " value
            echo
        else
            read -r -p "${label}: " value
        fi

        if [[ -n "${value}" ]]; then
            printf '%s' "${value}"
            return
        fi

        echo "El valor no puede estar vacío." >&2
    done
}

prepare_ddns() {
    local app_dir="$1"
    local env_file="${app_dir}/.env"
    local api_token domains

    touch "${env_file}"
    chmod 600 "${env_file}"

    api_token="$(read_env_value "${env_file}" "CLOUDFLARE_API_TOKEN")"
    if [[ -z "${api_token}" ]]; then
        echo "DDNS requiere un token de API de Cloudflare con permisos mínimos de Zone / DNS / Edit."
        api_token="$(prompt_required_value "Introduce CLOUDFLARE_API_TOKEN" true)"
        upsert_env_value "${env_file}" "CLOUDFLARE_API_TOKEN" "${api_token}"
    fi

    domains="$(read_env_value "${env_file}" "DOMAINS")"
    if [[ -z "${domains}" ]]; then
        domains="$(prompt_required_value "Introduce los FQDN separados por comas (por ejemplo, casa.example.com)" false)"
        upsert_env_value "${env_file}" "DOMAINS" "${domains}"
    fi
}

deploy_app() {
    local app="$1"
    local app_dir="${APPS_DIR}/${app}"
    local launcher="${app_dir}/run_${app}.sh"

    echo
    echo "Desplegando: ${app}"

    if [[ "${app}" == "ddns" ]]; then
        prepare_ddns "${app_dir}"
    fi

    if [[ -f "${launcher}" ]]; then
        (
            cd "${app_dir}"
            bash "${launcher}"
        )
    else
        (
            cd "${app_dir}"
            "${COMPOSE_COMMAND[@]}" up -d
        )
    fi
}

show_menu() {
    local index

    echo "Aplicaciones Docker disponibles:"
    for index in "${!APPS[@]}"; do
        printf '  %d) %s\n' "$((index + 1))" "${APPS[index]}"
    done
    echo "  A) Instalar todas"
    echo "  0) Salir sin instalar"
}

main() {
    local selection index app

    [[ -d "${APPS_DIR}" ]] || {
        echo "Error: no existe el directorio de aplicaciones: ${APPS_DIR}" >&2
        exit 1
    }

    require_compose
    discover_apps

    if [[ "${#APPS[@]}" -eq 0 ]]; then
        echo "No se han encontrado aplicaciones con Docker Compose en ${APPS_DIR}."
        exit 0
    fi

    show_menu
    read -r -p "Selecciona una opción: " selection

    case "${selection}" in
        0)
            echo "No se ha instalado ninguna aplicación."
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
                echo "Opción no válida." >&2
                exit 1
            fi
            ;;
    esac
}

main "$@"
