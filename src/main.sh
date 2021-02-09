#!/usr/bin/env bash

bgen:import barg

bgen:import ../lib/rnchr/_utils.sh
bgen:import ../lib/rnchr/env.sh
bgen:import ../lib/rnchr/container.sh
bgen:import ../lib/rnchr/secret.sh

main() {
    rnchr_env_args
    barg.subcommand container cmd_container "Operations on containers"
    barg.subcommand secret cmd_secret "Operations on secrets"
    barg.subcommand exec rnchr_container_exec "Executes a command on a remote container"

    local rancher_url=
    local rancher_access_key=
    local rancher_secret_key=
    local rancher_env=

    local subcommand=
    local subcommand_args=()

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    # Call subcommand if any
    "$subcommand" \
        --url "$rancher_url" \
        --access-key "$rancher_access_key" \
        --secret-key "$rancher_secret_key" \
        --env "$rancher_env" \
        "${subcommand_args[@]}"
}

cmd_container() {
    rnchr_env_args
    barg.subcommand exec rnchr_container_exec "Executes a command on a remote container"

    local rancher_url=
    local rancher_access_key=
    local rancher_secret_key=
    local rancher_env=

    local subcommand=
    local subcommand_args=()

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    # Call subcommand if any
    "$subcommand" \
        --url "$rancher_url" \
        --access-key "$rancher_access_key" \
        --secret-key "$rancher_secret_key" \
        --env "$rancher_env" \
        "${subcommand_args[@]}"
}

cmd_secret() {
    rnchr_env_args
    barg.subcommand inspect rnchr_secret_get "Prints JSON of the given secret"
    barg.subcommand create rnchr_secret_create "Create a new secret"
    barg.subcommand rm rnchr_secret_delete "Delete secret"
    barg.subcommand sync rnchr_secret_sync "Sync secrets from dotenv file"

    local rancher_url=
    local rancher_access_key=
    local rancher_secret_key=
    local rancher_env=

    local subcommand=
    local subcommand_args=()

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    # Call subcommand if any
    "$subcommand" \
        --url "$rancher_url" \
        --access-key "$rancher_access_key" \
        --secret-key "$rancher_secret_key" \
        --env "$rancher_env" \
        "${subcommand_args[@]}"
}
