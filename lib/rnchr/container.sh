#!/usr/bin/env bash

bgen:import _utils.sh
bgen:import api.sh
bgen:import stack.sh

rnchr_container_get() {
    _rnchr_env_args
    barg.arg name \
        --required \
        --value=CONTAINER \
        --desc="Container to get the ID of"
    barg.arg container_var \
        --long=id-var \
        --value=variable \
        --desc="Set the shell variable instead"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local name=
    local container_var=
    barg.parse "$@"

    local __container_json=

    # If the name contains a slash, assume it's <stack>/<service>
    if [[ "$name" =~ \/ ]]; then
        local containers=
        rnchr_service_get_containers --containers-var containers "$name" || return

        __container_json=$(jq -Mr '.[0] | select(. != null)' <<<"$containers")
    else
        local query=
        if [[ "$name" =~ ^1i[[:digit:]]+ ]]; then
            query="id=${name#1i}"
        else
            query="name=$name"
        fi

        local __response=
        _rnchr_pass_env_args rnchr_env_api \
            --response-var __response \
            "containers" \
            --get --data-urlencode "$query" || return

        if [[ "$__response" && "$(jq -Mr '.data | length' <<<"$__response")" -ne 0 ]]; then
            __container_json=$(jq -Mr '.data[0] | select(. != null)' <<<"$__response")
        fi
    fi

    if [[ "$__container_json" ]]; then
        if [[ "$id_var" ]]; then
            butl.set_var "$container_var" "$__container_json"
        else
            echo "$__container_json"
        fi

        return
    fi

    butl.fail "Container ${BUTL_ANSI_UNDERLINE}$name${BUTL_ANSI_RESET_UNDERLINE} not found"
}

rnchr_container_get_id() {
    _rnchr_env_args
    barg.arg name \
        --required \
        --value=CONTAINER \
        --desc="Container to get the ID of"
    barg.arg id_var \
        --long=id-var \
        --value=variable \
        --desc="Set the shell variable instead"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local name=
    local id_var=
    barg.parse "$@"

    local __container_id=
    if [[ "$name" =~ ^1i[[:digit:]]+ ]]; then
        __container_id=$name
    elif [[ "$name" =~ \/ ]]; then
        local service_json=
        rnchr_service_get --service-var service_json "$name" || return

        __container_id=$(jq -Mr '.instanceIds[0] | select(. != null)' <<<"$service_json")
    else
        local __response=
        _rnchr_pass_env_args rnchr_env_api \
            --response-var __response \
            "containers" \
            --get --data-urlencode "name=$name" || return

        if [[ "$__response" && "$(jq -Mr '.data | length' <<<"$__response")" -ne 0 ]]; then
            __container_id=$(jq -Mr '.data[0].id | select(. != null)' <<<"$__response")
        fi
    fi

    if [[ "$__container_id" ]]; then
        if [[ "$id_var" ]]; then
            butl.set_var "$id_var" "$__container_id"
        else
            echo "$__container_id"
        fi

        return
    fi

    butl.fail "Container ${BUTL_ANSI_UNDERLINE}$name${BUTL_ANSI_RESET_UNDERLINE} not found"
}

rnchr_container_list() {
    _rnchr_env_args
    barg.arg containers_var \
        --long=containers-var \
        --value=variable \
        --desc="Set the shell variable instead"
    barg.arg all_containers \
        --long=all \
        --short=a \
        --desc="Show all containers"
    barg.arg all_running \
        --long=running \
        --short=r \
        --desc="Show containers that are starting or restarting"
    barg.arg system_containers \
        --long=system \
        --short=s \
        --desc="Show system containers"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local containers_var=
    local all_containers=
    local all_running=
    local system_containers=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local params=(--data-urlencode "limit=-1")
    if ! ((all_containers)); then
        if ((all_running)); then
            params+=(
                --data-urlencode "state_ne=error"
                --data-urlencode "state_ne=purged"
                --data-urlencode "state_ne=removed"
                --data-urlencode "state_ne=stopped"
            )
        else
            params+=(--data-urlencode "state=running")
        fi
    fi

    if ! ((system_containers)); then
        params+=(--data-urlencode "system=false")
    fi

    local _response=
    _rnchr_pass_env_args rnchr_env_api \
        --response-var _response \
        "containers" --get \
        "${params[@]}" || return

    local _containers
    _containers=$(jq -Mc '.data' <<<"$_response")

    if [[ "$containers_var" ]]; then
        butl.set_var "$containers_var" "$_containers"
    else
        echo "$_containers"
    fi
}

rnchr_container_logs() {
    _rnchr_env_args
    barg.arg container \
        --required \
        --value=CONTAINER \
        --desc="Container name or container ID"
    barg.arg lines \
        --long=lines \
        --short=n \
        --value=NUMBER \
        --default=50 \
        --desc="Number of lines to show"
    barg.arg since \
        --long=since \
        --short=s \
        --value=TIMESTAMP \
        --desc="Show longs since timestamp"
    barg.arg follow \
        --long=follow \
        --short=f \
        --desc="If set, follows container logs"
    barg.arg timestamps \
        --long=timestamps \
        --short=t \
        --desc="If set, also shows timestamps"
    barg.arg raw \
        --long=raw \
        --desc="Do not preprocess rancher output"
    barg.arg colorize_stderr \
        --long=distinct-stderr \
        --desc="Colorize stderr in red"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local container=
    local lines=
    local follow=
    local since=
    local timestamps=
    local raw=
    local colorize_stderr=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local container_id=
    _rnchr_pass_env_args rnchr_container_get_id \
        --id-var container_id "$container" || return

    local payload
    payload=$(jq -Mnc '{
        "follow": false,
        "lines": 100,
        "since": "",
        "timestamps": false
    }')

    if [[ "$lines" ]]; then
        payload=$(jq -Mc --argjson linecount "$lines" '.lines = $linecount' <<<"$payload") || return
    fi

    if [[ "$follow" ]]; then
        payload=$(jq -Mc '.follow = true' <<<"$payload") || return
    fi

    if [[ "$since" ]]; then
        since=$(jq -Mc --arg ts "$since" '.since = $ts' <<<"$payload") || return
    fi

    if [[ "$timestamps" ]]; then
        timestamps=$(jq -Mc '.timestamps = true' <<<"$payload") || return
    fi

    local response=
    _rnchr_pass_env_args rnchr_env_api \
        --response-var response \
        "containers/$container_id/?action=logs" \
        -X POST -d "$payload" || return

    local token
    token=$(jq -Mr '.token' <<<"$response") || return

    local url
    url=$(jq -Mr '.url' <<<"$response") || return

    if ((raw)); then
        : | websocat -n "${url}?token=${token}" 2>/dev/null || true
    else
        while read -r line; do
            if [[ "${line::2}" == "01" ]]; then
                echo -e "${line:3}" >&1
            elif ((colorize_stderr)); then
                echo -e "${BUTL_ANSI_BRRED}${line:3}${BUTL_ANSI_RESET}" >&2
            else
                echo -e "${line:3}" >&2
            fi
        done < <(: | websocat -n "${url}?token=${token}" 2>/dev/null || true)
    fi
}

rnchr_container_exec() {
    _rnchr_env_args
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

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local command=()
    local container=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    if ! ((${#command[@]})); then
        return 0
    fi

    local container_id=
    _rnchr_pass_env_args rnchr_container_get_id \
        --id-var container_id "$container" || return

    local stdout_marker="__STDOUT_${RANDOM}__"
    local stderr_marker="__STDERR_${RANDOM}__"

    local cmd=
    cmd=$(printf '%q ' "${command[@]}")

    local cmd_wrapper="
        tmp=\$(mktemp -d)
        ($cmd) 1>\"\$tmp/stdout\" 2>\"\$tmp/stderr\"
        err=\$?
        cat \"\$tmp/stdout\"
        printf \"$stdout_marker\"
        cat \"\$tmp/stderr\"
        printf \"$stderr_marker\"
        echo \$err
        rm -r \"\$tmp\"
    "

    local query
    query=$(jq --arg cmd "$cmd_wrapper" -Mnc '{
        "attachStdin": false,
        "attachStdout": true,
        "command": ["bash", "-c", $cmd],
        "tty": false
    }') || return

    local response=
    _rnchr_pass_env_args rnchr_env_api \
        --response-var response \
        "containers/$container_id/?action=execute" \
        -X POST -d "$query" || return

    local token
    token=$(jq -Mr '.token' <<<"$response") || return

    local url
    url=$(jq -Mr '.url' <<<"$response") || return

    local output
    output=$(: | websocat -n "${url}?token=${token}") || return
    output=$(base64 -d <<<"$output" | tr -d '\0') || return

    : "${output%%"${stdout_marker}"*}"
    : "${_#$'\x01\x01'?}"
    : "${_#$'\x01'?}"
    : "${_%$'\x01'?}"
    local stdout=${_%[[:space:]]}
    if [[ "$stdout" =~ [^[:cntrl:]] ]]; then
        printf '%b\n' "$stdout"
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

    : "${output##*"${stderr_marker}"}"
    local rc="${_//[![:digit:]]/}"

    if [[ ! "$rc" ]]; then
        return 1
    else
        return "$rc"
    fi
}
