#!/usr/bin/env bash

reset_compose_stack() {
    local -a compose_command=("$@")

    run_logged_command "Docker Compose down" "${compose_command[@]}" down --volumes --remove-orphans
    pull_compose_images "${compose_command[@]}"
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
    local output_file

    output_file="$(mktemp)"
    if "$@" >"${output_file}" 2>&1; then
        log_info "${description} completed successfully."
    else
        log_command_failure "${description}" "${output_file}"
        rm -f "${output_file}"
        return 1
    fi
    rm -f "${output_file}"
}

pull_compose_images() {
    local -a compose_command=("$@")
    local -a images=()
    local image image_output index=0 total output_file

    output_file="$(mktemp)"
    if image_output="$("${compose_command[@]}" config --images 2>"${output_file}")"; then
        rm -f "${output_file}"
    else
        log_command_failure "Docker Compose image discovery" "${output_file}"
        rm -f "${output_file}"
        return 1
    fi

    while IFS= read -r image; do
        [[ -n "${image}" ]] || continue
        images+=("${image}")
    done < <(printf '%s\n' "${image_output}" | awk 'NF && !seen[$0]++')
    total="${#images[@]}"

    if (( total == 0 )); then
        run_logged_command "Docker Compose pull" "${compose_command[@]}" pull --quiet
        return
    fi

    log_info "Docker Compose pull: downloading ${total} images."
    for image in "${images[@]}"; do
        output_file="$(mktemp)"
        if docker pull --quiet "${image}" >"${output_file}" 2>&1; then
            index=$((index + 1))
            log_info "Docker Compose pull: image ${index}/${total} completed (${image})."
        else
            log_command_failure "Docker Compose pull for image ${image}" "${output_file}"
            rm -f "${output_file}"
            return 1
        fi
        rm -f "${output_file}"
    done

    log_info "Docker Compose pull completed successfully: ${total}/${total} images downloaded."
}

log_command_failure() {
    local description="$1"
    local output_file="$2"
    local line

    line="$(awk 'NF { last = $0 } END { print last }' "${output_file}")"
    if [[ -n "${line}" ]]; then
        log_error "${description} failed: ${line}"
    else
        log_error "${description} failed."
    fi
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
