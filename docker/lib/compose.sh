#!/usr/bin/env bash

reset_compose_stack() {
    local -a compose_command=("$@")

    run_logged_command "Docker Compose down" "${compose_command[@]}" down --volumes --remove-orphans
    run_logged_command "Docker Compose pull" "${compose_command[@]}" pull
    run_logged_command "Docker Compose up" "${compose_command[@]}" up --detach --force-recreate --renew-anon-volumes
    log_compose_containers "${compose_command[@]}"
}

remove_container_if_exists() {
    local container_name="$1"

    docker container rm --force "${container_name}" >/dev/null 2>&1 || true
}

run_logged_command() {
    local description="$1"
    shift

    log_info "${description} started."
    if "$@" 2>&1 | log_command_output "${description}"; then
        log_info "${description} completed successfully."
    else
        log_error "${description} failed."
        return 1
    fi
}

log_command_output() {
    local description="$1"
    local line

    while IFS= read -r line; do
        log_info "${description}: ${line}"
    done
}

log_compose_containers() {
    local -a compose_command=("$@")
    local container_id container_status

    while IFS= read -r container_id; do
        [[ -n "${container_id}" ]] || continue
        container_status="$(docker inspect --format 'name={{.Name}} image={{.Config.Image}} image_id={{.Image}} status={{.State.Status}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}} started_at={{.State.StartedAt}}' "${container_id}")"
        log_info "Container status: ${container_status}"
    done < <("${compose_command[@]}" ps --quiet)
}
