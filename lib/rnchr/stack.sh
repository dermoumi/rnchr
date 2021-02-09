#!/usr/bin/env bash

bgen:import _utils.sh
bgen:import api.sh

rnchr_stack_get() {
    rnchr_env_args
    barg.arg name \
        --required \
        --value=STACK \
        --desc="Stack to inspect"

    local rancher_url=
    local rancher_access_key=
    local rancher_secret_key=
    local rancher_env=
    local name=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local query=
    if [[ "$name" =~ 1st[[:digit:]]+ ]]; then
        query="id=$name"
    else
        query="name=$name"
    fi

    local r_resp=
    rnchr_env_api \
        --url "$rancher_url" \
        --access-key "$rancher_access_key" \
        --secret-key "$rancher_secret_key" \
        --env "$rancher_env" \
        "stacks" --get --data-urlencode "$query" >/dev/null || return

    if [[ "$r_resp" && "$(jq -Mr '.data | length' <<<"$r_resp")" -gt 0 ]]; then
        local json
        json=$(jq -Mc '.data[0] | select(. != null)' <<<"$r_resp") || return

        if [[ "$json" ]]; then
            if butl.is_declared r_stack; then
                # shellcheck disable=SC2034
                r_stack=$json
            fi

            echo "$json"
            return
        fi
    fi

    butl.fail "Stack ${BUTL_ANSI_UNDERLINE}$name${BUTL_ANSI_RESET_UNDERLINE} not found"
}

rnchr_stack_get_services() {
    rnchr_env_args
    barg.arg name \
        --required \
        --value=STACK \
        --desc="Stack to get the services of"

    local rancher_url=
    local rancher_access_key=
    local rancher_secret_key=
    local rancher_env=
    local name=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local query=
    if [[ "$name" =~ 1st[[:digit:]]+ ]]; then
        query="id=$name"
    else
        query="name=$name"
    fi

    local r_stack=
    rnchr_stack_get \
        --url "$rancher_url" \
        --access-key "$rancher_access_key" \
        --secret-key "$rancher_secret_key" \
        --env "$rancher_env" \
        "$name" >/dev/null || return

    local stack_id
    stack_id=$(jq -Mr '.id | select(. != null)' <<<"$r_stack")

    local r_resp=
    rnchr_env_api \
        --url "$rancher_url" \
        --access-key "$rancher_access_key" \
        --secret-key "$rancher_secret_key" \
        --env "$rancher_env" \
        "stacks/$stack_id/services" >/dev/null || return

    r_resp=$(jq -Mc '.data | select(. != null)' <<<"$r_resp") || return

    if [[ "$r_resp" ]]; then
        if butl.is_declared r_services; then
            # shellcheck disable=SC2034
            r_services=$r_resp
        fi

        echo "$r_resp"
        return
    fi

    echo "[]"
}
