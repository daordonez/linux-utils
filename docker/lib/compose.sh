#!/usr/bin/env bash

reset_compose_stack() {
    local -a compose_command=("$@")

    "${compose_command[@]}" down --volumes --remove-orphans
    "${compose_command[@]}" pull
    "${compose_command[@]}" up --detach --force-recreate --renew-anon-volumes
}

remove_container_if_exists() {
    local container_name="$1"

    docker container rm --force "${container_name}" >/dev/null 2>&1 || true
}
