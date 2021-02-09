#!/usr/bin/env bash

bgen:import _utils.sh
bgen:import api.sh
bgen:import stack.sh

rnchr_container_get_id() {
    rnchr_env_args
    barg.arg name \
        --required \
        --value=CONTAINER \
        --desc="Container to get the ID of"

    local rancher_url=
    local rancher_access_key=
    local rancher_secret_key=
    local rancher_env=
    local name=
    barg.parse "$@"

    if [[ "$name" =~ 1i[[:digit:]]+ ]]; then
        echo "$name"
        return
    fi

    # If the name contains a slash, assume it's <stack>/<service>
    if [[ "$name" =~ \/ ]]; then
        local stack_name=${name%%\/*}
        local service_name=${name##*\/}

        local r_services=
        rnchr_stack_get_services \
            --url "$rancher_url" \
            --access-key "$rancher_access_key" \
            --secret-key "$rancher_secret_key" \
            --env "$rancher_env" \
            "$stack_name" >/dev/null || return

        if [[ "$(jq -Mr '. | length' <<<"$r_services")" -gt 0 ]]; then
            # Select the first of potentially many containers for this service
            container_id=$(jq -Mr --arg service "$service_name" '
                .[] | select(.name == $service) | .instanceIds[0] | select(. != null)
            ' <<<"$r_services")

            if [[ "$container_id" ]]; then
                if butl.is_declared r_container_id; then
                    # shellcheck disable=SC2034
                    r_container_id=$container_id
                fi

                echo "$container_id"
                return
            fi
        fi
    fi

    local r_resp=
    rnchr_env_api \
        --url "$rancher_url" \
        --access-key "$rancher_access_key" \
        --secret-key "$rancher_secret_key" \
        --env "$rancher_env" \
        "containers" \
        --get --data-urlencode "name=$name" >/dev/null || return

    if [[ "$r_resp" && "$(jq -Mr '.data | length' <<<"$r_resp")" -ne 0 ]]; then
        local container_id
        container_id=$(jq -Mr '.data[0].id | select(. != null)' <<<"$r_resp")

        if [[ "$container_id" ]]; then
            if butl.is_declared r_container_id; then
                # shellcheck disable=SC2034
                r_container_id=$container_id
            fi

            echo "$container_id"
            return
        fi
    fi

    butl.fail "Container ${BUTL_ANSI_UNDERLINE}$name${BUTL_ANSI_RESET_UNDERLINE} not found"
}

rnchr_container_exec() {
    rnchr_env_args
    barg.arg container \
        --required \
        --value=CONTAINER \
        --desc="Container name or container ID"
    barg.arg command \
        --required \
        --multi \
        --value=ARGS \
        --allow-dash \
        --desc="Commands to execute"

    local command=()
    local container=
    local rancher_url=
    local rancher_access_key=
    local rancher_secret_key=
    local rancher_env=
    barg.parse "$@"

    if ! ((${#command[@]})); then
        return 0
    fi

    local r_container_id=
    rnchr_container_get_id "$container" >/dev/null || return

    local stdout_marker="__STDOUT_${RANDOM}__"
    local stderr_marker="__STDERR_${RANDOM}__"

    local cmd_wrapper="
        tmp=\$(mktemp -d)
        (${command[*]}) 1>\"\$tmp/stdout\" 2>\"\$tmp/stderr\"
        err=\$?
        cat \"\$tmp/stdout\"
        printf \"$stdout_marker\"
        cat \"\$tmp/stderr\"
        printf \"$stderr_marker\"
        echo \$err
        rm -rf \"\$tmp\"
    "

    local query
    query=$(jq --arg cmd "$cmd_wrapper" -Mnc '{
        "attachStdin":false,
        "attachStdout":true,
        "command":["bash", "-c", $cmd],
        "tty":false}
    ')

    local r_resp=
    rnchr_env_api \
        --url "$rancher_url" \
        --access-key "$rancher_access_key" \
        --secret-key "$rancher_secret_key" \
        --env "$rancher_env" \
        "containers/$r_container_id/?action=execute" \
        -X POST -d "$query" >/dev/null || return

    local token
    token=$(jq -Mr '.token' <<<"$r_resp")

    local url
    url=$(jq -Mr '.url' <<<"$r_resp")

    local output
    output=$(websocat -E "${url}?token=${token}" | base64 -d | tr -d '\0')

    : "${output%%"${stdout_marker}"*}"
    : "${_#$'\x01\x01'?}"
    : "${_#$'\x01'?}"
    : "${_%$'\x01'?}"
    local stdout=${_%[[:space:]]}
    if [[ "$stdout" =~ [^[:cntrl:]] ]]; then
        printf '%b\n' "$stdout"
        # printf '%b\n' "$(cat -etv <<<"$stdout")"
    fi

    : "${output##*"${stdout_marker}"}"
    : "${_%%"${stderr_marker}"*}"
    : "${_#$'\x01\x01'?}"
    : "${_#$'\x01'?}"
    : "${_%$'\x01'?}"
    local stderr=${_%[[:space:]]}
    if [[ "$stderr" =~ [^[:cntrl:]] ]]; then
        printf '%b\n' "$stderr" >&2
    fi

    return "${output##*"${stderr_marker}"}"
}
