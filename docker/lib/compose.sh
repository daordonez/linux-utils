#!/usr/bin/env bash

reset_compose_stack() {
    local -a compose_command=("$@")

    "${compose_command[@]}" down --volumes --remove-orphans
    "${compose_command[@]}" pull
    "${compose_command[@]}" up --detach --force-recreate --renew-anon-volumes
}
