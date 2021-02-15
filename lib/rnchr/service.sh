#!/usr/bin/env bash

rnchr_service_get() {
    _rnchr_env_args
    barg.arg _service \
        --required \
        --value=container \
        --desc="Container to get the ID of"
    barg.arg service_var \
        --long=service-var \
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

    local _service=
    local service_var=
    barg.parse "$@"

    # If the name contains a slash, assume it's <stack>/<service>
    if [[ "$_service" =~ \/ ]]; then
        local stack_name=${_service%%\/*}
        local service_name=${_service##*\/}

        local query=
        if [[ "$service_name" =~ ^1s[[:digit:]]+ ]]; then
            query="id=$service_name"
        else
            query="name=$service_name"
        fi

        # pre-load rancher env ID before running co_run
        _rnchr_pass_args rnchr_env_get_id "$rancher_env" >/dev/null || return

        local _json_map=()
        butl.co_run _json_map \
            "_rnchr_pass_env_args rnchr_env_api 'services' --get \
                --data-urlencode 'limit=-1' --data-urlencode '$query'" \
            "_rnchr_pass_env_args rnchr_stack_get_id '$stack_name'" || return

        local _stack_id=${_json_map[1]}
        local _service_json=
        _service_json=$(jq -Mc --arg stackId "$_stack_id" \
            '.data[] | select(.stackId == $stackId)' <<<"${_json_map[0]}")

        if [[ "$_service_json" ]]; then
            if [[ "$service_var" ]]; then
                butl.set_var "$service_var" "$_service_json"
            else
                echo "$_service_json"
            fi

            return
        fi
    elif [[ "$_service" =~ ^1s[[:digit:]]+ ]]; then
        local _services_json=
        _rnchr_pass_env_args rnchr_env_api \
            --response-var _services_json \
            "services" --get \
            --data-urlencode "id=$_service" \
            --data-urlencode "limit=-1" || return

        if [[ "$_services_json" && "$(jq -Mr '.data | length' <<<"$_services_json")" -ne 0 ]]; then
            local _service_json
            _service_json=$(jq -Mc --arg service "$_service" \
                '.data[] | select(.id == $service) | .' <<<"$_services_json") || return

            if [[ "$_service_json" ]]; then
                if [[ "$service_var" ]]; then
                    butl.set_var "$service_var" "$_service_json"
                else
                    echo "$_service_json"
                fi

                return
            fi
        fi
    fi

    butl.fail "Service ${BUTL_ANSI_UNDERLINE}$_service${BUTL_ANSI_RESET_UNDERLINE} not found"
}

rnchr_service_get_id() {
    _rnchr_env_args
    barg.arg _service \
        --required \
        --value=container \
        --desc="Container to get the ID of"
    barg.arg _service_id_var \
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

    local _service=
    local _service_id_var=
    barg.parse "$@"

    local __service_id=
    if [[ "$_service" =~ ^1s[[:digit:]]+ ]]; then
        __service_id=$_service
    else
        local __service_json=
        _rnchr_pass_env_args rnchr_service_get --service-var __service_json "$_service" || return
        __service_id=$(jq -Mr '.id' <<<"$__service_json") || return
    fi

    if [[ "$_service_id_var" ]]; then
        butl.set_var "$_service_id_var" "$__service_id"
    else
        echo "$__service_id"
    fi
}

rnchr_service_stop() {
    _rnchr_env_args
    barg.arg service \
        --required \
        --value=Service \
        --desc="Service to await the containers of"
    barg.arg await \
        --short=w \
        --long=wait \
        --desc="Wait until all containers of the service have stopped"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local service=
    local await=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local service_id=
    _rnchr_pass_env_args rnchr_service_get_id --id-var service_id "$service" || return

    butl.muffle_all _rnchr_pass_env_args rnchr_env_api \
        "services/$service?action=deactivate" -X POSt || return

    if ((await)); then
        rnchr_service_wait_for_containers_to_stop "$service_id"
    fi
}

rnchr_service_remove() {
    _rnchr_env_args
    barg.arg service \
        --required \
        --value=Service \
        --desc="Service to await the containers of"
    barg.arg await \
        --short=w \
        --long=wait \
        --desc="Wait until all containers of the service have stopped"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local service=
    local await=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local service_id=
    _rnchr_pass_env_args rnchr_service_get_id --id-var service_id "$service" || return

    butl.muffle_all _rnchr_pass_env_args rnchr_env_api \
        "services/$service" -X DELETE || return

    if ((await)); then
        rnchr_service_wait_for_containers_to_stop "$service_id"
    fi
}

rnchr_service_get_containers() {
    _rnchr_env_args
    barg.arg service \
        --required \
        --value=SERVICE \
        --desc="Service to get the containers of"
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

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local service=
    local containers_var=
    local all_containers=
    local all_running=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local _args=()
    if ((all_containers)); then
        _args+=(--all)
    fi
    if ((all_running)); then
        _args+=(--running)
    fi

    # pre-load rancher env ID before running co_run
    _rnchr_pass_args rnchr_env_get_id "$rancher_env" >/dev/null || return

    local _json_map=()
    butl.co_run _json_map \
        "_rnchr_pass_env_args rnchr_container_list ${_args[*]}" \
        "_rnchr_pass_env_args rnchr_service_get_id '$service'" || return

    local __service_containers=${_json_map[0]}
    local service_id=${_json_map[1]}

    __service_containers=$(jq -Mc --arg service "$service_id" '[
        .[] | select((.serviceIds != null) and (.serviceIds[] | contains ($service)))
    ]' <<<"$__service_containers") || return

    if [[ "$containers_var" ]]; then
        butl.set_var "$containers_var" "$__service_containers"
    else
        echo "$__service_containers"
    fi
}

rnchr_service_wait_for_containers_to_stop() {
    _rnchr_env_args
    barg.arg service \
        --required \
        --value=Service \
        --desc="Service to await the containers of"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local service=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local service_id=
    if [[ "$service" =~ 1s[[:digit:]]+ ]]; then
        service_id=$service
    else
        local service_json=
        _rnchr_pass_env_args rnchr_service_get --service-var service_json "$service" || return
        service_id=$(jq -Mr '.id' <<<"$service_json") || return
    fi

    # Wait for all services to reach our desired state
    butl.log_debug "Waiting for containers of service $service to stop..."

    while [[ "$(_rnchr_pass_env_args rnchr_service_get_containers "$service_id" --running | jq -Mrc '.[]')" ]]; do
        sleep 1
    done
}

rnchr_service_exists() {
    _rnchr_env_args
    barg.arg service \
        --required \
        --value=Service \
        --desc="Service to check"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local service=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    # If the name contains a slash, assume it's <stack>/<service>
    if [[ "$service" =~ \/ ]]; then
        local stack_name=${service%%\/*}
        local service_name=${service##*\/}

        local stack_services=
        _rnchr_pass_env_args rnchr_stack_get_services \
            --services-var stack_services \
            "$stack_name" || return

        local service_json=
        service_json=$(jq -Mc --arg service "$service_name" \
            '.[] | select(.name == $service)' <<<"$stack_services") || return

        if [[ "$service_json" ]]; then
            return 0
        fi
    elif [[ "$service" =~ 1s[[:digit:]]+ ]]; then
        local response=
        _rnchr_pass_env_args rnchr_env_api \
            --response-var response \
            "services" \
            --get --data-urlencode "id=$service" || return

        if [[ "$response" && "$(jq -Mr '.data | length' <<<"$response")" -ne 0 ]]; then
            local service_json=
            service_json=$(jq -Mc --arg service "$service_name" \
                '.data[] | select(.id == $service) | .' <<<"$response") || return

            if [[ "$service_json" ]]; then
                return 0
            fi
        fi
    fi

    return 1
}

rnchr_service_logs() {
    _rnchr_env_args
    barg.arg service \
        --required \
        --value=SERVICE \
        --desc="Service ID or <STACK>/<NAME>"
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
    barg.arg all_running \
        --long=running \
        --short=r \
        --desc="Show containers that are starting or restarting"
    barg.arg colorize_stderr \
        --long=distinct-stderr \
        --desc="Colorize stderr in red"
    barg.arg no_colors \
        --long=no-colors \
        --desc="Disable colors"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local service=
    local lines=
    local follow=
    local since=
    local timestamps=
    local all_running=
    local colorize_stderr=
    local no_colors=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local _args=()
    if ((all_running)); then
        _args+=(--running)
    else
        _args+=(--all)
    fi

    local service_containers=
    _rnchr_pass_env_args rnchr_service_get_containers \
        --containers-var service_containers \
        "${_args[@]}" "$service" || return

    local container_ids=
    butl.split_lines container_ids "$(jq -Mr '.[].id' <<<"$service_containers")" || return
    butl.log_debug "Containers to follow logs of: $(butl.join_by ',' "${container_ids[@]}")"

    local _args=(--lines="$lines" --since="$since")
    if ((timestamps)); then
        _args+=(--timestamps)
    fi
    if ((follow)); then
        _args+=(--follow)
    fi
    if ! ((no_colors)) && ((colorize_stderr)); then
        _args+=(--distinct-stderr)
    fi

    if ((${#container_ids[@]} == 1)); then
        _rnchr_pass_env_args rnchr_container_logs "${_args[@]}" "${container_ids[0]}"
    elif ((${#container_ids[@]})); then
        local pids=()
        local container_id
        local index=1

        local container_colors=(
            "$BUTL_ANSI_GREEN"
            "$BUTL_ANSI_YELLOW"
            "$BUTL_ANSI_BLUE"
            "$BUTL_ANSI_MAGENTA"
            "$BUTL_ANSI_CYAN"
            "$BUTL_ANSI_BRGREEN"
            "$BUTL_ANSI_BRYELLOW"
            "$BUTL_ANSI_BRBLUE"
            "$BUTL_ANSI_BRMAGENTA"
            "$BUTL_ANSI_BRCYAN"
        )

        # shellcheck disable=SC2034
        if ((no_colors)); then
            local col_reset=
            local col_container=
            local col_err=
        else
            local col_reset=$BUTL_ANSI_RESET
            local col_container=$BUTL_ANSI_BRCYAN

            if ((colorize_stderr)); then
                local col_err=$BUTL_ANSI_BRRED
            else
                local col_err=$BUTL_ANSI_RESET
            fi
        fi

        # shellcheck disable=SC2034
        local container_id
        # shellcheck disable=SC2034
        for container_id in "${container_ids[@]}"; do
            # shellcheck disable=SC2034
            if ! ((no_colors)); then
                local col_index="$((index % ${#container_colors[@]}))"
                local col_container="${container_colors[$col_index]}"
            fi

            # Putting the whole subshell in an eval to avoid shfmt breaking it when minifying
            while read -r line; do
                if [[ "${line::2}" == "01" ]]; then
                    printf "%b%-10s %b%s%b\n" "$col_container" "$container_id" "$col_reset" "${line:3}" "$col_reset" >&1 || :
                else
                    printf "%b%-10s %b%s%b\n" "$col_container" "$container_id" "$col_err" "${line:3}" "$col_reset" >&2 || :
                fi
            done < <(_rnchr_pass_env_args rnchr_container_logs "${_args[@]}" --raw "$container_id") &

            pids+=("$!")

            ((index = index + 1))
        done

        local pid
        for pid in "${pids[@]}"; do
            wait "$pid" || true
        done
    fi
}
