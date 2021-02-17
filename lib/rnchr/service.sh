#!/usr/bin/env bash

bgen:import ./api.sh
bgen:import ./env.sh
bgen:import ./stack.sh
bgen:import ./secret.sh
bgen:import ./certificate.sh
bgen:import ./container.sh

rnchr_service_list() {
    _rnchr_env_args
    barg.arg services_var \
        --long=services-var \
        --value=VARIABLE \
        --desc="Shell variable to store services list into"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local services_var=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local _response=
    _rnchr_pass_env_args rnchr_env_api \
        --response-var _response \
        "services" --get \
        --data-urlencode "removed_null=1" \
        --data-urlencode "limit=-1" || return

    local __services_list
    __services_list=$(jq -Mc '.data' <<<"$_response")

    if [[ "$services_var" ]]; then
        butl.set_var "$services_var" "$__services_list"
    else
        echo "$__services_list"
    fi
}

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
    barg.arg _use_stack_list \
        --hidden \
        --long=use-stack-list \
        --value=JSON
    barg.arg _use_service_list \
        --hidden \
        --long=use-service-list \
        --value=JSON

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
    local _use_stack_list=
    local _use_service_list=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local stack_name=
    local service_name=
    if [[ "$_service" =~ \/ ]]; then
        stack_name=${_service%%\/*}
        service_name=${_service##*\/}
    else
        service_name=$_service
    fi

    if [[ "$service_name" =~ ^1s[[:digit:]]+ ]]; then
        stack_name=
    elif [[ ! "$stack_name" ]]; then
        butl.fail "Service must be either an ID or <STACK>/<SERVICE>"
        return
    fi

    local _service_json=
    if [[ "$stack_name" ]]; then
        local stack_id=
        if [[ "$_use_stack_list" && "$_use_service_list" ]]; then
            _rnchr_pass_args rnchr_stack_get_id "$stack_name" \
                --use-stack-list "$_use_stack_list" --id-var stack_id || return

            _service_json=$(jq -Mc --arg stackId "$stack_id" --arg name "$service_name" \
                '.[] | select(.stackId == $stackId) | select(.name == $name)' <<<"$_use_service_list")
        elif [[ "$_use_stack_list" ]]; then
            _rnchr_pass_args rnchr_stack_get_id "$stack_name" \
                --use-stack-list "$_use_stack_list" --id-var stack_id || return

            local _services_json=
            _rnchr_pass_env_args rnchr_env_api \
                --response-var _services_json \
                "services" --get \
                --data-urlencode "name=$service_name" \
                --data-urlencode "stackId=$stack_id" \
                --data-urlencode "removed_null=1" \
                --data-urlencode "limit=-1" || return

            _service_json=$(jq -Mc '.data[0] | select(. != null)' <<<"$_services_json") || return
        elif [[ "$_use_service_list" ]]; then
            _rnchr_pass_args rnchr_stack_get_id "$stack_name" --id-var stack_id || return

            _service_json=$(jq -Mc --arg stackId "$stack_id" --arg name "$service_name" \
                '.[] | select(.stackId == $stackId) | select(.name == $name)' <<<"$_use_service_list")
        else
            # preload rancher env ID before running co_run
            _rnchr_pass_args rnchr_env_get_id "$rancher_env" >/dev/null || return

            local _json_map=()

            # shellcheck disable=SC2016,SC1004
            butl.co_run _json_map \
                '_rnchr_pass_env_args rnchr_env_api "services" --get \
                    --data-urlencode "limit=-1" --data-urlencode "name=$service_name"' \
                '_rnchr_pass_env_args rnchr_stack_get_id "$stack_name"' || return

            stack_id=${_json_map[1]}
            _service_json=$(jq -Mc --arg stackId "$stack_id" \
                '.data[] | select(.stackId == $stackId)' <<<"${_json_map[0]}")
        fi
    else
        if [[ "$_use_service_list" ]]; then
            _service_json=$(jq -Mc --arg id "$service_name" \
                '.[] | select(.id == $id)' <<<"$_use_service_list")
        else
            local _services_json=
            _rnchr_pass_env_args rnchr_env_api \
                --response-var _services_json \
                "services" --get \
                --data-urlencode "id=${service_name#1s}" \
                --data-urlencode "removed_null=1" \
                --data-urlencode "limit=-1" || return

            _service_json=$(jq -Mc --arg service "$service_name" \
                '.data[] | select(.id == $service) | select(. != null)' <<<"$_services_json") || return
        fi
    fi

    if [[ "$_service_json" ]]; then
        if [[ "$service_var" ]]; then
            butl.set_var "$service_var" "$_service_json"
        else
            echo "$_service_json"
        fi

        return
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
    barg.arg _use_stack_list \
        --hidden \
        --long=use-stack-list \
        --value=JSON
    barg.arg _use_service_list \
        --hidden \
        --long=use-service-list \
        --value=JSON

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
    local _use_stack_list=
    local _use_service_list=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local __service_id=
    if [[ "$_service" =~ ^1s[[:digit:]]+ ]]; then
        __service_id=$_service
    else
        local __service_json=
        _rnchr_pass_env_args rnchr_service_get "$_service" --service-var __service_json \
            --use-stack-list "$_use_stack_list" --use-service-list "$_use_service_list" || return

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
        "services/$service_id" -X DELETE || return

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
    if [[ "$service" =~ ^1s[[:digit:]]+ ]]; then
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
    barg.arg _use_stack_list \
        --hidden \
        --long=use-stack-list \
        --value=JSON
    barg.arg _use_service_list \
        --hidden \
        --long=use-service-list \
        --value=JSON

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local service=
    local _use_stack_list=
    local _use_service_list=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local stack_name=
    local service_name=
    if [[ "$service" =~ \/ ]]; then
        stack_name=${service%%\/*}
        service_name=${service##*\/}
    else
        service_name=$service
    fi

    if [[ "$service_name" =~ ^1s[[:digit:]]+ ]]; then
        stack_name=
    elif [[ ! "$stack_name" ]]; then
        butl.fail "Service must be either an ID or <STACK>/<SERVICE>"
        return
    fi

    local service_json=
    if [[ "$stack_name" ]]; then
        if [[ "$_use_service_list" ]]; then
            local stack_id=
            _rnchr_pass_env_args rnchr_stack_get_id "$stack_name" \
                --id-var stack_var --use-stack-list "$_use_stack_list" || return

            service_json=$(jq -Mc --arg service "$service_name" --arg stackId "$stack_id" \
                '.[] | select(.stackId == $stackId) | select(.name == $service)' <<<"$_use_service_list") || return
        else
            local stack_services=
            _rnchr_pass_env_args rnchr_stack_get_services "$stack_name" \
                --services-var stack_services --use-stack-list "$_use_stack_list" || return

            service_json=$(jq -Mc --arg service "$service_name" \
                '.[] | select(.name == $service)' <<<"$stack_services") || return
        fi
    else
        if [[ "$_use_service_list" ]]; then
            service_json=$(jq -Mc --arg service "$service_name" \
                '.[] | select(.id == $service) | .' <<<"$_use_service_list") || return
        else
            local response=
            _rnchr_pass_env_args rnchr_env_api \
                --response-var response \
                "services" --get \
                --data-urlencode "removed_null=1" \
                --data-urlencode "id=${service_name#1s}" || return

            service_json=$(jq -Mc --arg service "$service_name" \
                '.data[] | select(.id == $service) | .' <<<"$response") || return
        fi
    fi

    [[ "$service_json" ]]
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
                    printf "%b%-10s %b%s%b\n" "$col_container" "$container_id" \
                        "$col_reset" "${line:3}" "$col_reset" >&1 || :
                else
                    printf "%b%-10s %b%s%b\n" "$col_container" "$container_id" \
                        "$col_err" "${line:3}" "$col_reset" >&2 || :
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

rnchr_service_create() {
    _rnchr_env_args
    barg.arg __stack_service \
        --required \
        --value=STACK/NAME \
        --desc="Service and stack names"
    barg.arg __service_compose_json \
        --long=service-compose-json \
        --value=SERVICE_COMPOSE \
        --desc="Service compose JSON"
    barg.arg __stack_compose_json \
        --long=stack-compose-json \
        --value=STACK_COMPOSE \
        --value=SERVICE \
        --desc="Service from stack compose JSON"
    barg.arg __scale_override \
        --long=scale \
        --value=SCALE \
        --desc="Service scale"
    barg.arg __no_start_on_create \
        --long=no-start-on-create \
        --desc="If set, service won't start on creation"
    barg.arg __force_start_on_create \
        --long=force-start-on-create \
        --desc="If set, forces service to start on creation"
    barg.arg __no_update_links \
        --long=no-update-links \
        --desc="If set, does not upgrade service links after deploying"
    barg.arg __id_var \
        --implies=__silent \
        --value=VARIABLE \
        --long=id-var \
        --desc="Shell variable to store the service ID"
    barg.arg __service_var \
        --implies=__silent \
        --value=VARIABLE \
        --long=stack-var \
        --desc="Shell variable to store the service JSON"
    barg.arg __silent \
        --long=silent \
        --short=s \
        --desc="Do not output service JSON after creation"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local __stack_service=
    local __service_compose_json=
    local __scale_override=
    local __no_start_on_create=
    local __force_start_on_create=
    local __stack_compose_json=()
    local __no_update_links=
    local __id_var=
    local __service_var=
    local __silent=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    if [[ "$__stack_service" =~ \/ ]]; then
        local _stack=${__stack_service%%\/*}
        local _service=${__stack_service##*\/}
    else
        butl.fail "Name should be <STACK_NAME>/<SERVICE_NAME>"
        return
    fi

    local scale=1
    local start_on_create=true

    local __launch_config=

    if [[ ! "$__service_compose_json" ]] && ((${#__stack_compose_json[@]} > 0)); then
        local __stack_compose=
        __stack_compose=${__stack_compose_json[0]}

        local __target_service=
        __target_service=${__stack_compose_json[1]}

        _rnchr_pass_env_args rnchr_service_util_extract_service_compose \
            "$__stack_compose" "$__target_service" --compose-var __service_compose_json || return

        if [[ ! "$__service_compose_json" ]]; then
            butl.fail "Compose file does not have any entry for service $__target_service"
            return
        fi
    fi

    if [[ ! "$__service_compose_json" ]]; then
        butl.fail "No service configuration was supplied"
        return
    fi

    local __service_image
    __service_image=$(jq -Mr '.image' <<<"$__service_compose_json") || return

    if [[ "$__service_image" == "rancher/dns-service" ]]; then
        local __args=(--service-compose-json "$__service_compose_json")

        if ((__force_start_on_create)); then
            __args+=(--force-start-on-create)
        elif ((__no_start_on_create)); then
            __args+=(--no-start-on-create)
        fi

        if ((__no_update_links)); then
            __args+=(--no-update-links)
        fi

        if [[ "$__id_var" ]]; then
            __args+=(--id-var "$__id_var")
        fi

        if [[ "$__service_var" ]]; then
            __args+=(--service-var "$__service_var")
        fi

        if [[ "$__silent" ]]; then
            __args+=(--silent)
        fi

        _rnchr_pass_env_args rnchr_service_create_dns_service "$__stack_service" "${__args[@]}"
        return
    elif [[ "$__service_image" == "rancher/external-service" ]]; then
        butl.log_warning "Creating external services is not implented yet"
        return
    elif [[ "$__service_image" =~ ^rancher/lb-service- ]]; then
        local __args=(--service-compose-json "$__service_compose_json")

        if ((__force_start_on_create)); then
            __args+=(--force-start-on-create)
        elif ((__no_start_on_create)); then
            __args+=(--no-start-on-create)
        fi

        if ((__no_update_links)); then
            __args+=(--no-update-links)
        fi

        if [[ "$__id_var" ]]; then
            __args+=(--id-var "$__id_var")
        fi

        if [[ "$__service_var" ]]; then
            __args+=(--service-var "$__service_var")
        fi

        if [[ "$__silent" ]]; then
            __args+=(--silent)
        fi

        _rnchr_pass_env_args rnchr_service_create_load_balancer "$__stack_service" "${__args[@]}"
        return
    fi

    _rnchr_pass_env_args rnchr_service_util_to_launch_config "$__service_compose_json" \
        --config-var __launch_config || return

    scale=$(jq -Mr '.scale // 1' <<<"$__service_compose_json")
    start_on_create=$(jq -Mr '.start_on_create // true' <<<"$__service_compose_json")

    if [[ "$__scale_override" ]]; then
        scale=$__scale_override
    fi

    if ((__force_start_on_create)); then
        start_on_create=true
    elif ((__no_start_on_create)); then
        start_on_create=false
    fi

    local _stack_id
    _rnchr_pass_env_args rnchr_stack_get_id --id-var _stack_id "$_stack" || return

    local __payload
    __payload=$(
        jq -Mnc \
            --arg name "$_service" \
            --argjson scale "$scale" \
            --argjson startOnCreate "$start_on_create" \
            --arg stackId "$_stack_id" \
            --argjson launchConfig "$__launch_config" \
            '{
                "type": "service",
                "name": $name,
                "scale": $scale,
                "stackId": $stackId,
                "startOnCreate": $startOnCreate,
                "assignServiceIpAddress": false,
                "launchConfig": $launchConfig,
                "secondaryLaunchConfigs": []
            }'
    ) || return

    local __response=
    _rnchr_pass_env_args rnchr_env_api --response-var __response \
        "/service" -X POST -d "$__payload" || return

    local __service_id
    __service_id=$(jq -Mr '.id' <<<"$__response")

    if [[ "$__id_var" ]]; then

        butl.set_var "$__id_var" "$__service_id"
    fi

    if [[ "$__service_var" ]]; then
        butl.set_var "$__service_var" "$__response"
    elif ! ((__silent)); then
        echo "$__response"
    fi

    if ! ((__no_update_links)) && [[ "$__service_compose_json" ]]; then
        _rnchr_pass_env_args rnchr_service_update_links "$__service_id" \
            --service-compose-json "$__service_compose_json" || return
    fi
}

rnchr_service_create_dns_service() {
    _rnchr_env_args
    barg.arg __stack_service \
        --required \
        --value=STACK/NAME \
        --desc="Service and stack names"
    barg.arg __service_compose_json \
        --long=service-compose-json \
        --value=SERVICE_COMPOSE \
        --desc="Service compose JSON"
    barg.arg __stack_compose_json \
        --long=stack-compose-json \
        --value=STACK_COMPOSE \
        --value=SERVICE \
        --desc="Service from stack compose JSON"
    barg.arg __no_start_on_create \
        --long=no-start-on-create \
        --desc="If set, service won't start on creation"
    barg.arg __force_start_on_create \
        --long=force-start-on-create \
        --desc="If set, forces service to start on creation"
    barg.arg __no_update_links \
        --long=no-update-links \
        --desc="If set, does not upgrade service links after deploying"
    barg.arg __id_var \
        --implies=__silent \
        --value=VARIABLE \
        --long=id-var \
        --desc="Shell variable to store the service ID"
    barg.arg __service_var \
        --implies=__silent \
        --value=VARIABLE \
        --long=stack-var \
        --desc="Shell variable to store the service JSON"
    barg.arg __silent \
        --long=silent \
        --short=s \
        --desc="Do not output service JSON after creation"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local __stack_service=
    local __service_compose_json=
    local __no_start_on_create=
    local __force_start_on_create=
    local __stack_compose_json=()
    local __no_update_links=
    local __id_var=
    local __service_var=
    local __silent=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    if [[ "$__stack_service" =~ \/ ]]; then
        local _stack=${__stack_service%%\/*}
        local _service=${__stack_service##*\/}
    else
        butl.fail "Name should be <STACK_NAME>/<SERVICE_NAME>"
        return
    fi

    local _stack_id
    _rnchr_pass_env_args rnchr_stack_get_id --id-var _stack_id "$_stack" || return

    local start_on_create=true

    if [[ ! "$__service_compose_json" ]] && ((${#__stack_compose_json[@]} > 0)); then
        local stack_compose=
        stack_compose=${__stack_compose_json[0]}

        local target_service=
        target_service=${__stack_compose_json[1]}

        _rnchr_pass_env_args rnchr_service_util_extract_service_compose \
            "$stack_compose" "$target_service" --compose-var __service_compose_json || return

        if [[ ! "$__service_compose_json" ]]; then
            butl.fail "Compose file does not have any entry for service $target_service"
            return
        fi
    fi

    if [[ ! "$__service_compose_json" ]]; then
        butl.fail "No service configuration was supplied"
        return
    fi

    start_on_create=$(jq -Mr '.start_on_create // true' <<<"$__service_compose_json")

    if ((__force_start_on_create)); then
        start_on_create=true
    elif ((__no_start_on_create)); then
        start_on_create=false
    fi

    local __payload
    __payload=$(
        jq -Mnc \
            --arg name "$_service" \
            --argjson startOnCreate "$start_on_create" \
            --arg stackId "$_stack_id" \
            '{
                "type": "dnsService",
                "name": $name,
                "stackId": $stackId,
                "startOnCreate": $startOnCreate,
                "assignServiceIpAddress": false,
            }'
    ) || return

    butl.muffle_all _rnchr_pass_env_args rnchr_env_api "/dnsservice" -X POST -d "$__payload" || return

    if ! ((__no_update_links)); then
        _rnchr_pass_env_args rnchr_service_update_links "$__service_id" \
            --service-compose-json "$__service_compose_json" || return
    fi
}

rnchr_service_create_load_balancer() {
    _rnchr_env_args
    barg.arg __stack_service \
        --required \
        --value=STACK/NAME \
        --desc="Service and stack names"
    barg.arg __service_compose_json \
        --long=service-compose-json \
        --value=SERVICE_COMPOSE \
        --desc="Service compose JSON"
    barg.arg __stack_compose_json \
        --long=stack-compose-json \
        --value=STACK_COMPOSE \
        --value=SERVICE \
        --desc="Service from stack compose JSON"
    barg.arg __scale_override \
        --long=scale \
        --value=SCALE \
        --desc="Service scale"
    barg.arg __no_start_on_create \
        --long=no-start-on-create \
        --desc="If set, service won't start on creation"
    barg.arg __force_start_on_create \
        --long=force-start-on-create \
        --desc="If set, forces service to start on creation"
    barg.arg __no_update_links \
        --long=no-update-links \
        --desc="If set, does not upgrade service links after deploying"
    local stack_id
    stack_id=$(jq -Mr '.id' <<<"$service_json") || return

    barg.arg __id_var \
        --implies=__silent \
        --value=VARIABLE \
        --long=id-var \
        --desc="Shell variable to store the service ID"
    barg.arg __service_var \
        --implies=__silent \
        --value=VARIABLE \
        --long=stack-var \
        --desc="Shell variable to store the service JSON"
    barg.arg __silent \
        --long=silent \
        --short=s \
        --desc="Do not output service JSON after creation"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local __stack_service=
    local __service_compose_json=
    local __scale_override=
    local __no_start_on_create=
    local __force_start_on_create=
    local __stack_compose_json=()
    local __no_update_links=
    local __id_var=
    local __service_var=
    local __silent=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    if [[ "$__stack_service" =~ \/ ]]; then
        local _stack=${__stack_service%%\/*}
        local _service=${__stack_service##*\/}
    else
        butl.fail "Name should be <STACK_NAME>/<SERVICE_NAME>"
        return
    fi

    local _stack_id
    _rnchr_pass_env_args rnchr_stack_get_id --id-var _stack_id "$_stack" || return

    local scale=1
    local start_on_create=true

    if [[ ! "$__service_compose_json" ]] && ((${#__stack_compose_json[@]} > 0)); then
        local stack_compose=
        stack_compose=${__stack_compose_json[0]}

        local target_service=
        target_service=${__stack_compose_json[1]}

        _rnchr_pass_env_args rnchr_service_util_extract_service_compose \
            "$stack_compose" "$target_service" --compose-var __service_compose_json || return

        if [[ ! "$__service_compose_json" ]]; then
            butl.fail "Compose file does not have any entry for service $target_service"
            return
        fi
    fi

    if [[ ! "$__service_compose_json" ]]; then
        butl.fail "No service configuration was supplied"
        return
    fi

    local __lb_config
    _rnchr_pass_env_args rnchr_service_util_to_lb_config "$__service_compose_json" \
        --config-var __lb_config --stack "$_stack_id" || return

    local __launch_config
    _rnchr_pass_env_args rnchr_service_util_to_launch_config "$__service_compose_json" \
        --config-var __launch_config || return

    scale=$(jq -Mr '.scale // 1' <<<"$__service_compose_json")
    start_on_create=$(jq -Mr '.start_on_create // true' <<<"$__service_compose_json")

    if [[ "$__scale_override" ]]; then
        scale=$__scale_override
    fi

    if ((__force_start_on_create)); then
        start_on_create=true
    elif ((__no_start_on_create)); then
        start_on_create=false
    fi

    local __payload
    __payload=$(
        jq -Mnc \
            --arg name "$_service" \
            --argjson startOnCreate "$start_on_create" \
            --argjson scale "$scale" \
            --arg stackId "$_stack_id" \
            --argjson launchConfig "$__launch_config" \
            --argjson lbConfig "$__lb_config" \
            '{
                "type": "loadBalancerService",
                "name": $name,
                "scale": $scale,
                "stackId": $stackId,
                "startOnCreate": $startOnCreate,
                "assignServiceIpAddress": false,
                "lbConfig": $lbConfig,
                "launchConfig": $launchConfig
            }'
    ) || return

    butl.muffle_all _rnchr_pass_env_args rnchr_env_api "/loadbalancerservices" -X POST -d "$__payload" || return

    if ! ((__no_update_links)); then
        _rnchr_pass_env_args rnchr_service_update_links "$__service_id" \
            --service-compose-json "$__service_compose_json" || return
    fi
}

rnchr_service_upgrade() {
    _rnchr_env_args
    barg.arg stack_service \
        --required \
        --value=STACK/NAME \
        --desc="Service and stack names"
    barg.arg service_compose_json \
        --long=service-compose-json \
        --value=SERVICE_COMPOSE \
        --desc="Service compose JSON"
    barg.arg stack_compose_json \
        --long=stack-compose-json \
        --value=STACK_COMPOSE \
        --value=SERVICE \
        --desc="Service from stack compose JSON"
    barg.arg batch_size_override \
        --long=batch-size \
        --value=INTEGER \
        --desc="How many replacement containers to deploy at a time"
    barg.arg interval_override \
        --long=interval \
        --value=MILLISECONDS \
        --desc="Time between each container batch deployment"
    barg.arg no_start_first \
        --long=no-start-first \
        --desc="If set, old container will be shut down before the new container starts"
    barg.arg force_start_first \
        --long=force-start-first \
        --desc="If set, forces new container to start before shutting down old containers"
    barg.arg no_update_links \
        --long=no-update-links \
        --desc="If set, does not upgrade service links after deploying"
    barg.arg finish_upgrade \
        --long=finish-upgrade \
        --desc="Finishes upgrade"
    barg.arg finish_upgrade_timeout \
        --implies=finish_upgrade \
        --long=finish-upgrade-timeout \
        --value=SECONDS \
        --desc="Finishes upgrade but fails if exceeds given time"
    barg.arg ensure_secrets \
        --implies=finish_upgrade \
        --long=ensure-secrets \
        --desc="Makes sure secrets are mounted after deploying"
    barg.arg _use_payload \
        --hidden \
        --long=use-payload \
        --value=PAYLOAD

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local stack_service=
    local service_compose_json=
    local batch_size_override=
    local interval_override=
    local no_start_first=
    local force_start_first=
    local stack_compose_json=()
    local no_update_links=
    local finish_upgrade=
    local finish_upgrade_timeout=
    local ensure_secrets=
    local _use_payload=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local service_json
    _rnchr_pass_env_args rnchr_service_get --service-var service_json "$stack_service" || return

    local service_id
    service_id=$(jq -Mr '.id' <<<"$service_json") || return

    local payload
    if [[ "$_use_payload" ]]; then
        payload=$_use_payload
    else
        local batch_size=1
        local interval_millis=2000
        local start_first=false

        local launch_config=

        if [[ ! "$service_compose_json" ]] && ((${#stack_compose_json[@]} > 0)); then
            local stack_compose=
            stack_compose=${stack_compose_json[0]}

            local target_service=
            target_service=${stack_compose_json[1]}

            _rnchr_pass_env_args rnchr_service_util_extract_service_compose \
                "$stack_compose" "$target_service" --compose-var service_compose_json || return
        fi

        if [[ "$service_compose_json" ]]; then
            local service_image
            service_image=$(jq -Mr '.image' <<<"$service_compose_json") || return

            if [[ "$service_image" == "rancher/dns-service" ]]; then
                if ! ((no_update_links)); then
                    _rnchr_pass_env_args rnchr_service_update_links "$stack_service" \
                        --service-compose-json "$service_compose_json" || return
                fi

                return
            elif [[ "$service_image" == "rancher/external-service" ]]; then
                butl.log_warning "Updating external services is not implented yet"
                return
            elif [[ "$service_image" =~ ^rancher/lb-service- ]]; then
                local __args=(--service-compose-json "$service_compose_json")

                if ((no_start_first)); then
                    __args+=(--no-start-first)
                elif ((force_start_first)); then
                    __args+=(--force-start-first)
                fi

                if ((finish_upgrade)); then
                    __args+=(--finish-upgrade)
                fi

                if ((ensure_secrets)); then
                    __args+=(--ensure-secrets)
                fi

                if [[ "$batch_size_override" ]]; then
                    __args+=(--batch-size "$batch_size_override")
                fi

                if [[ "$interval_override" ]]; then
                    __args+=(--interval "$interval_override")
                fi

                if [[ "$finish_upgrade_timeout" ]]; then
                    __args+=(--finish-upgrade-timeout "$finish_upgrade_timeout")
                fi

                if [[ "$_use_payload" ]]; then
                    __args+=(--use-payload "$_use_payload")
                fi

                _rnchr_pass_env_args rnchr_service_upgrade_load_balancer "$stack_service" "${__args[@]}"
                return
            fi

            _rnchr_pass_env_args rnchr_service_util_to_launch_config "$service_compose_json" \
                --config-var launch_config || return

            batch_size=$(jq -Mr '.upgrade_strategy.batch_size // 1' <<<"$service_compose_json") || return
            interval_millis=$(jq -Mr '.upgrade_strategy.interval_millis // 2000' <<<"$service_compose_json") || return
            start_first=$(jq -Mr '.upgrade_strategy.start_first // false' <<<"$service_compose_json") || return
        else
            launch_config=$(jq -Mc '.upgrade.inServiceStrategy.launchConfig' <<<"$service_json") || return

            local service_image=
            service_image=$(jq -Mr '.imageUuid' <<<"$launch_config") || return

            if [[ "$service_image" == "rancher/dns-service" ]]; then
                if ! ((no_update_links)); then
                    _rnchr_pass_env_args rnchr_service_update_links "$stack_service" \
                        --service-compose-json "$service_compose_json" || return
                fi

                return
            elif [[ "$service_image" == "rancher/external-service" ]]; then
                butl.log_warning "Updating external services is not implented yet"
                return
            elif [[ "$service_image" =~ ^rancher/lb-service- ]]; then
                local __args=()

                if ((no_start_first)); then
                    __args+=(--no-start-first)
                elif ((force_start_first)); then
                    __args+=(--force-start-first)
                fi

                if ((finish_upgrade)); then
                    __args+=(--finish-upgrade)
                fi

                if ((ensure_secrets)); then
                    __args+=(--ensure-secrets)
                fi

                if [[ "$batch_size_override" ]]; then
                    __args+=(--batch-size "$batch_size_override")
                fi

                if [[ "$interval_override" ]]; then
                    __args+=(--interval "$interval_override")
                fi

                if [[ "$finish_upgrade_timeout" ]]; then
                    __args+=(--finish-upgrade-timeout "$finish_upgrade_timeout")
                fi

                if [[ "$_use_payload" ]]; then
                    __args+=(--use-payload "$_use_payload")
                fi

                if ((${#__args[@]})); then
                    _rnchr_pass_env_args rnchr_service_upgrade_load_balancer "$stack_service" "${__args[@]}" || return
                else
                    _rnchr_pass_env_args rnchr_service_upgrade_load_balancer "$stack_service" || return
                fi
                return
            fi

            batch_size=$(jq -Mc '.upgrade.inServiceStrategy.batchSize' <<<"$service_json") || return
            interval_millis=$(jq -Mc '.upgrade.inServiceStrategy.intervalMillis' <<<"$service_json") || return
            start_first=$(jq -Mc '.upgrade.inServiceStrategy.startFirst' <<<"$service_json") || return
        fi

        if [[ "$batch_size_override" ]]; then
            batch_size=$batch_size_override
        fi

        if [[ "$interval_override" ]]; then
            interval_millis=$interval_override
        fi

        if ((force_start_first)); then
            start_first=true
        elif ((no_start_first)); then
            start_first=false
        fi

        payload=$(
            jq -Mnc \
                --argjson startFirst "$start_first" \
                --argjson batchSize "$batch_size" \
                --argjson interval "$interval_millis" \
                --argjson launchConfig "$launch_config" \
                '{
                    "inServiceStrategy": {
                        "batchSize": $batchSize,
                        "intervalMillis": $interval,
                        "startFirst": $startFirst,
                        "launchConfig": $launchConfig
                    }
                }'
        ) || return
    fi

    butl.muffle_all _rnchr_pass_env_args rnchr_env_api \
        "/services/$service_id/?action=upgrade" -X POST -d "$payload" || return

    if ! ((no_update_links)); then
        _rnchr_pass_env_args rnchr_service_update_links "$stack_service" \
            --service-compose-json "$service_compose_json" || return
    fi

    if ((finish_upgrade)); then
        _rnchr_pass_env_args rnchr_service_finish_upgrade "$service_id" --timeout="$finish_upgrade_timeout" || return

        if ((ensure_secrets)); then
            _rnchr_pass_env_args rnchr_service_ensure_secrets_mounted "$service_id" --use-payload "$payload" || return
        fi
    fi
}

rnchr_service_upgrade_load_balancer() {
    _rnchr_env_args
    barg.arg stack_service \
        --required \
        --value=STACK/NAME \
        --desc="Service and stack names"
    barg.arg service_compose_json \
        --long=service-compose-json \
        --value=SERVICE_COMPOSE \
        --desc="Service compose JSON"
    barg.arg stack_compose_json \
        --long=stack-compose-json \
        --value=STACK_COMPOSE \
        --value=SERVICE \
        --desc="Service from stack compose JSON"
    barg.arg batch_size_override \
        --long=batch-size \
        --value=INTEGER \
        --desc="How many replacement containers to deploy at a time"
    barg.arg interval_override \
        --long=interval \
        --value=MILLISECONDS \
        --desc="Time between each container batch deployment"
    barg.arg no_start_first \
        --long=no-start-first \
        --desc="If set, old container will be shut down before the new container starts"
    barg.arg force_start_first \
        --long=force-start-first \
        --desc="If set, forces new container to start before shutting down old containers"
    barg.arg no_update_links \
        --long=no-update-links \
        --desc="If set, does not upgrade service links after deploying"
    barg.arg finish_upgrade \
        --long=finish-upgrade \
        --desc="Finishes upgrade"
    barg.arg finish_upgrade_timeout \
        --implies=finish_upgrade \
        --long=finish-upgrade-timeout \
        --value=SECONDS \
        --desc="Finishes upgrade but fails if exceeds given time"
    barg.arg ensure_secrets \
        --implies=finish_upgrade \
        --long=ensure-secrets \
        --desc="Makes sure secrets are mounted after deploying"
    barg.arg _use_payload \
        --hidden \
        --long=use-payload \
        --value=PAYLOAD

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local stack_service=
    local service_compose_json=
    local batch_size_override=
    local interval_override=
    local no_start_first=
    local force_start_first=
    local stack_compose_json=()
    local no_update_links=
    local finish_upgrade=
    local finish_upgrade_timeout=
    local ensure_secrets=
    local _use_payload=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local service_json
    _rnchr_pass_env_args rnchr_service_get --service-var service_json "$stack_service" || return

    local service_id
    service_id=$(jq -Mr '.id' <<<"$service_json") || return

    local stack_id
    stack_id=$(jq -Mr '.stackId' <<<"$service_json") || return

    local update_payload
    local upgrade_payload
    if [[ "$_use_payload" ]]; then
        update_payload=$(jq -Mc '.updatePayload' <<<"$_use_payload") || return
        upgrade_payload=$(jq -Mc '.upgradePayload' <<<"$_use_payload") || return
    else
        local batch_size=1
        local interval_millis=2000
        local start_first=false

        local launch_config=
        local lb_config=

        if [[ ! "$service_compose_json" ]] && ((${#stack_compose_json[@]} > 0)); then
            local stack_compose=
            stack_compose=${stack_compose_json[0]}

            local target_service=
            target_service=${stack_compose_json[1]}

            _rnchr_pass_env_args rnchr_service_util_extract_service_compose \
                "$stack_compose" "$target_service" --compose-var service_compose_json || return
        fi

        if [[ "$service_compose_json" ]]; then
            _rnchr_pass_env_args rnchr_service_util_to_launch_config "$service_compose_json" \
                --config-var launch_config || return

            _rnchr_pass_env_args rnchr_service_util_to_lb_config "$service_compose_json" \
                --config-var lb_config --stack "$stack_id" || return

            batch_size=$(jq -Mr '.upgrade_strategy.batch_size // 1' <<<"$service_compose_json") || return
            interval_millis=$(jq -Mr '.upgrade_strategy.interval_millis // 2000' <<<"$service_compose_json") || return
            start_first=$(jq -Mr '.upgrade_strategy.start_first // false' <<<"$service_compose_json") || return
        else
            launch_config=$(jq -Mc '.upgrade.inServiceStrategy.launchConfig' <<<"$service_json") || return
            lb_config=$(jq -Mc '.upgrade.inServiceStrategy.lbConfig' <<<"$service_json") || return

            batch_size=$(jq -Mc '.upgrade.inServiceStrategy.batchSize' <<<"$service_json") || return
            interval_millis=$(jq -Mc '.upgrade.inServiceStrategy.intervalMillis' <<<"$service_json") || return
            start_first=$(jq -Mc '.upgrade.inServiceStrategy.startFirst' <<<"$service_json") || return
        fi

        if [[ "$batch_size_override" ]]; then
            batch_size=$batch_size_override
        fi

        if [[ "$interval_override" ]]; then
            interval_millis=$interval_override
        fi

        if ((force_start_first)); then
            start_first=true
        elif ((no_start_first)); then
            start_first=false
        fi

        update_payload=$(
            jq -Mnc \
                --argjson lbConfig "$lb_config" \
                --argjson launchConfig "$launch_config" \
                '{
                   "lbConfig": $lbConfig,
                   "launchConfig": $launchConfig,
               }'
        )

        upgrade_payload=$(
            jq -Mnc \
                --argjson startFirst "$start_first" \
                --argjson batchSize "$batch_size" \
                --argjson interval "$interval_millis" \
                --argjson launchConfig "$launch_config" \
                '{
                    "inServiceStrategy": {
                        "batchSize": $batchSize,
                        "intervalMillis": $interval,
                        "startFirst": $startFirst,
                        "launchConfig": $launchConfig,
                    }
                }'
        ) || return
    fi

    butl.muffle_all _rnchr_pass_env_args rnchr_env_api \
        "/loadbalancerservices/$service_id" -X PUT -d "$update_payload" || return

    butl.muffle_all _rnchr_pass_env_args rnchr_env_api \
        "/loadbalancerservices/$service_id/?action=upgrade" -X POST -d "$upgrade_payload" || return

    if ! ((no_update_links)); then
        _rnchr_pass_env_args rnchr_service_update_links "$stack_service" \
            --service-compose-json "$service_compose_json" || return
    fi

    if ((finish_upgrade)); then
        _rnchr_pass_env_args rnchr_service_finish_upgrade "$service_id" --timeout="$finish_upgrade_timeout" || return

        if ((ensure_secrets)); then
            local payload=
            payload=$(
                jq -Mnc \
                    --argjson updatePayload "$update_payload" \
                    --argjson upgradePayload "$upgrade_payload" \
                    '{
                    updatePayload: $updatePayload,
                    upgradePayload: $upgradePayload
                }'
            )
            _rnchr_pass_env_args rnchr_service_ensure_secrets_mounted "$service_id" --use-payload "$payload" || return
        fi
    fi
}

rnchr_service_finish_upgrade() {
    _rnchr_env_args
    barg.arg stack_service \
        --required \
        --value=STACK/NAME \
        --desc="Service and stack names"
    barg.arg timeout \
        --long=timeout \
        --value=SECONDS \
        --desc="Finishes upgrade but fails if exceeds given time"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local stack_service=
    local timeout=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local service_id
    _rnchr_pass_env_args rnchr_service_get_id --id-var service_id "$stack_service" || return

    if _rnchr_pass_env_args rnchr_service_has_action "$service_id" upgrade; then
        return
    fi

    if [[ "$timeout" ]]; then
        butl.timeout "$timeout" \
            _rnchr_pass_env_args rnchr_service_wait_for_action "$service_id" finishupgrade || return
    else
        _rnchr_pass_env_args rnchr_service_wait_for_action "$service_id" finishupgrade || return
    fi

    _rnchr_pass_env_args rnchr_service_make_upgradable "$service_id" || return
}

rnchr_service_update_links() {
    _rnchr_env_args
    barg.arg stack_service \
        --required \
        --value=STACK/NAME \
        --desc="Service and stack names"
    barg.arg service_compose_json \
        --long=service-compose-json \
        --value=SERVICE_COMPOSE \
        --desc="Service compose JSON"
    barg.arg stack_compose_json \
        --long=stack-compose-json \
        --value=STACK_COMPOSE \
        --value=SERVICE \
        --desc="Service from stack compose JSON"
    barg.arg _use_stack_list \
        --hidden \
        --long=use-stack-list \
        --value=JSON
    barg.arg _use_service_list \
        --hidden \
        --long=use-service-list \
        --value=JSON

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local stack_service=
    local service_compose_json=
    local stack_compose_json=()
    local _use_stack_list=
    local _use_service_list=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    if [[ ! "$service_compose_json" ]] && ((${#stack_compose_json[@]} > 0)); then
        local stack_compose=
        stack_compose=${stack_compose_json[0]}

        local target_service=
        target_service=${stack_compose_json[1]}

        _rnchr_pass_env_args rnchr_service_util_extract_service_compose \
            "$stack_compose" "$target_service" --compose-var service_compose_json || return

        if [[ ! "$service_compose_json" ]]; then
            butl.fail "Compose file does not have any entry for service $target_service"
            return
        fi
    fi

    if [[ ! "$service_compose_json" ]]; then
        butl.fail "No service configuration was supplied"
        return
    fi

    local links_str
    links_str=$(jq -Mr "(.external_links // []) + (.links // []) | .[]" <<<"$service_compose_json")

    local links
    butl.split_lines links "$links_str" || return

    if ((${#links[@]})); then
        # preload rancher env ID before running co_run
        _rnchr_pass_args rnchr_env_get_id "$rancher_env" >/dev/null || return

        local stacks_list=
        local services_list=

        if [[ "$_use_service_list" && "$_use_stack_list" ]]; then
            stacks_list=$_use_stack_list
            services_list=$_use_service_list
        elif [[ "$_use_service_list" ]]; then
            services_list=$_use_service_list
            _rnchr_pass_env_args rnchr_stack_list --stacks-var stack_list || return
        elif [[ "$_use_stack_list" ]]; then
            stacks_list=$_use_stack_list
            _rnchr_pass_env_args rnchr_service_list --services-var service_list || return
        else
            # Retrieve stacks and services lists
            local json_map=()
            butl.co_run json_map \
                "_rnchr_pass_env_args rnchr_stack_list" \
                "_rnchr_pass_env_args rnchr_service_list" || return

            stacks_list=${json_map[0]}
            services_list=${json_map[1]}
        fi

        # Retrieve stack and service info
        local service_id=
        local service_name=
        local stack_id=
        local stack_name=

        # Retrieve stack data
        if [[ "$stack_service" =~ \/ ]]; then
            stack_name=${stack_service%%/*}
            service_name=${stack_service#$stack_name\/}

            if [[ "$stack_name" =~ ^1st[[:digit:]]+ ]]; then
                stack_id=$stack_name
                stack_name=$(jq -Mr --arg id "$stack_id" \
                    '.[] | select(.id == $id) | .name' <<<"$stacks_list") || return
            else
                stack_id=$(jq -Mr --arg name "$stack_name" \
                    '.[] | select(.name == $name) | .id' <<<"$stacks_list") || return
            fi

            if [[ ! "$stack_id" ]]; then
                butl.fail "Stack $stack_name does not exist"
                return
            fi
        fi

        # Retrieve service data
        local service_json
        if [[ "$stack_service" =~ ^1s[[:digit:]]+ ]]; then
            service_id=$stack_service

            service_json=$(jq -Mc --arg id "$service_id" \
                '.[] | select(.id == $id)' <<<"$services_list") || return

            if [[ ! "$service_json" ]]; then
                butl.fail "Service $service_id does not exist"
                return
            fi

            service_name=$(jq -Mr '.name' <<<"$service_json") || return
            stack_id=$(jq -Mr '.stackId' <<<"$service_json") || return
            stack_name=$(jq -Mr --arg id "$stack_id" \
                '.[] | select(.id == $id) | .name' <<<"$stacks_list") || return
        elif [[ "$service_name" && "$stack_id" ]]; then
            service_json=$(jq -Mc --arg name "$service_name" --arg stackId "$stack_id" \
                '.[] | select((.name == $name) and (.stackId == $stackId))' <<<"$services_list") || return

            if [[ ! "$service_json" ]]; then
                butl.fail "Service $stack_name/$service_name does not exist"
                return
            fi

            service_id=$(jq -Mr '.id' <<<"$service_json") || return
        fi

        # Generate payload
        local payload='{"serviceLinks":[]}'

        # Loop over links
        local link
        for link in "${links[@]}"; do
            local alias=${link##*:}
            local target_service=${link%:$alias}

            # Get the target service ID
            local target_service_id
            local target_service_name
            if [[ "$target_service" =~ \/ ]]; then
                local stack=${target_service%%/*}
                local service=${target_service#$stack\/}

                local target_stack_id
                target_stack_id=$(jq -Mr --arg name "$stack" \
                    '.[] | select(.name == $name) | .id' <<<"$stacks_list") || return

                local target_service_json
                target_service_json=$(jq -Mc --arg name "$service" --arg stackId "$target_stack_id" \
                    '.[] | select((.name == $name) and (.stackId == $stackId))' <<<"$services_list") || return

                if [[ ! "$target_service_json" ]]; then
                    butl.fail "Target service $target_service does not exist"
                    return
                fi

                target_service_id=$(jq -Mr '.id' <<<"$target_service_json") || return
                target_service_name=$service
            else
                local target_service_json
                target_service_json=$(jq -Mc --arg name "$target_service" --arg stackId "$stack_id" \
                    '.[] | select((.name == $name) and (.stackId == $stackId))' <<<"$services_list") || return

                if [[ ! "$target_service_json" ]]; then
                    butl.fail "Target service $target_service does not exist"
                    return
                fi

                target_service_id=$(jq -Mr '.id' <<<"$target_service_json") || return
                target_service_name=$(jq -Mr '.name' <<<"$target_service_json") || return
            fi

            if [[ "$alias" == "$target_service_name" ]]; then
                local destination=
            else
                local destination=$alias
            fi

            butl.log_debug "Linking $target_service ($target_service_id) -> $alias"
            payload=$(
                jq -Mc --arg alias "$destination" --arg serviceId "$target_service_id" \
                    '.serviceLinks += [{
                        "name": $alias,
                        "serviceId": $serviceId,
                    }]' <<<"$payload"
            )
        done

        butl.muffle_all _rnchr_pass_env_args rnchr_env_api \
            "/services/$service_id/?action=setservicelinks" -X POST -d "$payload" || return
    fi
}

rnchr_service_has_action() {
    _rnchr_env_args
    barg.arg service \
        --required \
        --value=SERVICE \
        --desc="Service ID or <STACK>/<NAME>"
    barg.arg action \
        --required \
        --value=ACTION \
        --desc="Action to wait for for"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local service=
    local action=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local service_json=
    _rnchr_pass_env_args rnchr_service_get --service-var service_json "$service" || return

    local endpoint=
    endpoint=$(jq -Mr --arg action "$action" \
        '.actions[$action] | select(. != null)' <<<"$service_json") || return

    [[ "$endpoint" ]]
}

rnchr_service_wait_for_action() {
    _rnchr_env_args
    barg.arg service \
        --required \
        --value=SERVICE \
        --desc="Service ID or <STACK>/<NAME>"
    barg.arg action \
        --required \
        --value=ACTION \
        --desc="Action to wait for for"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local service=
    local action=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    butl.log_debug "Waiting for service $service to have action $action"

    local service_id=
    _rnchr_pass_env_args rnchr_service_get_id --id-var service_id "$service" || return

    while ! _rnchr_pass_env_args rnchr_service_has_action "$service_id" "$action"; do
        # Wait for 1 seconds before trying again
        sleep 1
    done
}

rnchr_service_make_upgradable() {
    _rnchr_env_args
    barg.arg service \
        --required \
        --value=SERVICE \
        --desc="Service ID or <STACK>/<NAME>"
    barg.arg await \
        --short=w \
        --long=wait \
        --desc="Wait for service to be in an upgradable state"

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

    butl.log_debug "Making Service $service reach an upgradable state"

    local service_json=
    _rnchr_pass_env_args rnchr_service_get --service-var service_json "$service" || return

    local endpoint=
    local action_endpoint=
    for action in finishupgrade rollback; do
        endpoint=$(jq -Mr --arg action "$action" \
            '.actions[$action] | select(. != null)' <<<"$service_json") || return

        if [[ "$endpoint" ]]; then
            action_endpoint=$endpoint
            : "Service ${BUTL_ANSI_UNDERLINE}$service${BUTL_ANSI_RESET_UNDERLINE}"
            butl.log_debug "$_ pending $action..."
            break
        fi
    done

    if [[ "$action_endpoint" ]]; then
        butl.muffle_all rnchr_env_api "$action_endpoint" -X POST || return

        if ((await)); then
            _rnchr_pass_env_args rnchr_stack_wait_for_service_action "$stack" upgrade "$service" || return
        fi
    fi
}

rnchr_service_ensure_secrets_mounted() {
    _rnchr_env_args
    barg.arg service \
        --required \
        --value=SERVICE \
        --desc="Service ID or <STACK>/<NAME>"
    barg.arg no_fix \
        --long=no-fix \
        --desc="Do not attempt to fix the service"
    barg.arg upgrade_args \
        --multi \
        --value=ARGS \
        --allow-dash \
        --desc="Upgrade arguments to pass to rncher_service_upgrade"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local service=
    local no_fix=
    local upgrade_args=()

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local service_id
    _rnchr_pass_env_args rnchr_service_get_id --id-var service_id "$service" || return

    local service_containers_json=
    rnchr_service_get_containers "$service_id" --containers-var service_containers_json || return

    local service_container_ids=
    service_container_ids=$(jq -Mr '.[].id' <<<"$service_containers_json") || return

    if [[ ! "$service_container_ids" ]]; then
        return 0
    fi

    local co_run_commands=()
    local container=
    while read -r container; do
        butl.log_debug "Checking container $service/$container..."
        co_run_commands+=("[[ \"\$(rnchr_container_exec '$container' ls /run/secrets/)\" ]]")
    done <<<"$service_container_ids"

    # shellcheck disable=SC2034
    local result

    if ! butl.co_run result "${co_run_commands[@]}"; then
        if ((no_fix)); then
            butl.log_error "Service $service does not have secrets mounted..."
            return 1
        fi

        butl.log_error "Service $service does not have secrets mounted, re-deploying..."

        if ((${#upgrade_args[@]})); then
            _rnchr_pass_env_args rnchr_service_upgrade "$service_id" "${upgrade_args[@]}" --finish-upgrade || return
        else
            _rnchr_pass_env_args rnchr_service_upgrade "$service_id" --finish-upgrade || return
        fi

        _rnchr_pass_env_args rnchr_service_wait_for_action "$service_id" upgrade || return
        _rnchr_pass_env_args rnchr_service_ensure_secrets_mounted "$service_id" || return
    fi
}

rnchr_service_util_to_lb_config() {
    _rnchr_env_args
    barg.arg __stack \
        --long stack \
        --value=STACK \
        --desc="Stack name"
    barg.arg __compose \
        --required \
        --value=JSON \
        --desc="Compose JSON to work with"
    barg.arg __config_var \
        --long=config-var \
        --value=VARIABLE \
        --desc="Shell variable to store the lbConfig into"
    barg.arg _use_stack_list \
        --hidden \
        --long=use-stack-list \
        --value=JSON
    barg.arg _use_service_list \
        --hidden \
        --long=use-service-list \
        --value=JSON

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local __stack=
    local __compose=
    local __config_var=
    local _use_stack_list=
    local _use_service_list=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    butl.log_debug "Converting service compose to rancher loadbalancer config"

    local stacks_list=
    local services_list=
    local certificates_list=

    if [[ "$_use_service_list" && "$_use_stack_list" ]]; then
        stacks_list=$_use_stack_list
        services_list=$_use_service_list
        _rnchr_pass_env_args rnchr_certificate_list --certificates-var certificates_list || return
    elif [[ "$_use_service_list" ]]; then
        services_list=$_use_service_list

        butl.co_run json_map \
            "_rnchr_pass_env_args rnchr_stack_list" \
            "_rnchr_pass_env_args rnchr_certificate_list" || return

        stacks_list=${json_map[0]}
        certificates_list=${json_map[1]}
    elif [[ "$_use_stack_list" ]]; then
        stacks_list=$_use_stack_list
        _rnchr_pass_env_args rnchr_service_list --services-var service_list || return

        butl.co_run json_map \
            "_rnchr_pass_env_args rnchr_service_list" \
            "_rnchr_pass_env_args rnchr_certificate_list" || return

        services_list=${json_map[0]}
        certificates_list=${json_map[1]}
    else
        # Retrieve stacks and services lists
        local json_map=()
        butl.co_run json_map \
            "_rnchr_pass_env_args rnchr_stack_list" \
            "_rnchr_pass_env_args rnchr_service_list" \
            "_rnchr_pass_env_args rnchr_certificate_list" || return

        stacks_list=${json_map[0]}
        services_list=${json_map[1]}
        certificates_list=${json_map[2]}
    fi

    local __default_cert_name=
    __default_cert_name=$(jq -Mr '.lb_config.default_cert | select(. != null)' <<<"$__compose") || return

    local __default_cert_id="null"
    if [[ "$__default_cert_name" ]]; then
        __default_cert_id=$(jq -Mr --arg name "$__default_cert_name" \
            '.[] | select(.name == $name) | .id | @json' <<<"$certificates_list") || return

        if [[ ! "$__default_cert_id" ]]; then
            butl.fail "Certificate $__default_cert_name was not found"
            return
        fi
    fi

    # TODO: Implement me
    local __certificate_ids='[]'

    local __port_rules_jsons=
    __port_rules_jsons=$(jq -Mrc '.lb_config.port_rules[]' <<<"$__compose") || return

    local __port_rules_array=
    butl.split_lines __port_rules_array "$__port_rules_jsons"

    local __port_rules='[]'
    if [[ "$__stack" ]] && ((${#__port_rules_array[@]})); then
        for __rule in "${__port_rules_array[@]}"; do
            local __service_name
            __service_name=$(jq -Mr '.service' <<<"$__rule") || return

            if ! [[ "$__service_name" =~ \/ ]]; then
                __service_name="$__stack/$__service_name"
            fi

            local _service_id=
            _rnchr_pass_env_args rnchr_service_get_id "$__service_name" \
                --use-stack-list "$stacks_list" --use-service-list "$services_list" \
                --id-var _service_id || continue

            local __backend_name=
            __backend_name=$(jq -Mc '.backend_name' <<<"$__rule") || return

            local __environment=
            __environment=$(jq -Mc '.environment' <<<"$__rule") || return

            local __hostname=
            __hostname=$(jq -Mc '.hostname' <<<"$__rule") || return

            local __path=
            __path=$(jq -Mc '.path' <<<"$__rule") || return

            local __priority=
            __priority=$(jq -Mc '.priority' <<<"$__rule") || return

            local __protocol=
            __protocol=$(jq -Mc '.protocol' <<<"$__rule") || return

            local __region=
            __region=$(jq -Mc '.region' <<<"$__rule") || return

            local __selector=
            __selector=$(jq -Mc '.selector' <<<"$__rule") || return

            local __source_port=
            __source_port=$(jq -Mc '.source_port' <<<"$__rule") || return

            local __target_port=
            __target_port=$(jq -Mc '.target_port' <<<"$__rule") || return

            __port_rules=$(
                jq -Mc \
                    --argjson backendName "$__backend_name" \
                    --argjson environment "$__environment" \
                    --argjson hostname "$__hostname" \
                    --argjson path "$__path" \
                    --argjson priority "$__priority" \
                    --argjson protocol "$__protocol" \
                    --argjson region "$__region" \
                    --argjson selector "$__selector" \
                    --arg serviceId "$_service_id" \
                    --argjson sourcePort "$__source_port" \
                    --argjson targetPort "$__target_port" \
                    '. += [{
                    backendName: $backendName,
                    environment: $environment,
                    hostname: $hostname,
                    path: $path,
                    priority: $priority,
                    protocol: $protocol,
                    region: $region,
                    selector: $selector,
                    serviceId: $serviceId,
                    sourcePort: $sourcePort,
                    targetPort: $targetPort
                }]' <<<"$__port_rules"
            ) || return
        done
    fi

    local __stickiness_policy=
    __stickiness_policy=$(jq -Mc '.lb_config.stickiness_policy' <<<"$__compose") || return

    local __config=
    __config=$(jq -Mc '.lb_config.config' <<<"$__compose") || return

    local __from_compose_lb_config
    __from_compose_lb_config=$(
        jq -Mnc \
            --argjson certificateIds "$__certificate_ids" \
            --argjson config "$__config" \
            --argjson defaultCertificateId "$__default_cert_id" \
            --argjson portRules "$__port_rules" \
            --argjson stickinessPolicy "$__stickiness_policy" \
            '{
                type: "lbConfig",
                certificateIds: $certificateIds,
                config: $config,
                defaultCertificateId: $defaultCertificateId,
                portRules: $portRules,
                stickinessPolicy: $stickinessPolicy
            }'
    ) || return

    if [[ "$__config_var" ]]; then
        butl.set_var "$__config_var" "$__from_compose_lb_config"
    else
        echo "$__from_compose_lb_config"
    fi
}

rnchr_service_util_to_launch_config() {
    _rnchr_env_args
    barg.arg __compose \
        --required \
        --value=JSON \
        --desc="Compose JSON to work with"
    barg.arg __config_var \
        --long=config-var \
        --value=VARIABLE \
        --desc="Shell variable to store the config into"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local __compose=
    local __config_var=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    # shellcheck disable=2001
    __compose=$(sed 's/\$\$/\$/g' <<<"$__compose") # faster on big strings?
    # __compose=${__compose//\$\$/\$}

    butl.log_debug "Converting service compose to rancher launch config"

    # Need to reference secrets by their IDs, so we fetch all of them from rancher and match
    local secrets=
    _rnchr_pass_env_args rnchr_service_util_reference_secrets "$__compose" --secrets-var secrets || return

    # Some extra values from rancher-compose
    local milli_cpu_reservation
    milli_cpu_reservation=$(jq -Mc '.milli_cpu_reservation' <<<"$__compose") || return
    local drain_timeout_ms
    drain_timeout_ms=$(jq -Mc '.drain_timeout_ms' <<<"$__compose") || return
    local start_on_create
    start_on_create=$(jq -Mc '.start_on_create' <<<"$__compose") || return

    # Health check only needs to be added IF defined
    local health_check
    health_check=$(jq -Mc '.health_check' <<<"$__compose")
    if [[ "$health_check" != "null" ]]; then
        local quorum
        quorum=$(jq -Mc '.recreate_on_quorum_strategy_config.quorum' <<<"$health_check") || return

        health_check=$(jq -Mc '{
            "type": "instanceHealthCheck",
            "healthyThreshold": .healthy_threshold,
            "initializingTimeout": .initializing_timeout,
            "interval": .interval,
            "name": null,
            "port": .port,
            "reinitializingTimeout": .reinitializing_timeout,
            "requestLine": .request_line,
            "responseTimeout": .response_timeout,
            "strategy": .strategy,
            "unhealthyThreshold": .unhealthy_threshold
        }' <<<"$health_check") || return

        if [[ "$quorum" && "$quorum" != "null" ]]; then
            health_check=$(jq -Mc --argjson quorum "$quorum" \
                '.recreateOnQuorumStrategyConfig = {
                    "type": "recreateOnQuorumStrategyConfig",
                    "quorum": $quorum,
                }' <<<"$health_check") || return
        fi
    fi

    # Build a new json with all the info from docker-compose
    # Most of it is just converting case and making sure there
    # are some non-null defaults when some values are not defined
    local __service_launch_config
    __service_launch_config=$(
        jq -Mc \
            --argjson startOnCreate "$start_on_create" \
            --argjson drainTimeoutMs "$drain_timeout_ms" \
            --argjson milliCpuReservation "$milli_cpu_reservation" \
            --argjson healthCheck "$health_check" \
            --argjson secrets "$secrets" \
            '{
            "type": "launchConfig",
            "kind": "container",
            "startOnCreate": $startOnCreate,
            "drainTimeoutMs": ($drainTimeoutMs // 0),
            "networkMode": (.network_mode // "managed"),
            "readOnly": (.read_only // false),
            "runInit": (.init // false),
            "stdinOpen": .stdin_open,
            "dataVolumes": .volumes,
            "imageUuid": ("docker:" + .image),
            "logConfig": {
                "type": "logConfig",
                "driver": .logging.driver,
                "config": (.logging.options // {})
            },
            "healthCheck": $healthCheck,
            "shmSize": .shm_size,
            "dataVolumesFrom": (.volumes_from // []),
            "dnsSearch": (.dns_search // []),
            "capAdd": (.cap_add // []),
            "capDrop": (.cap_drop // []),
            "cgroupParent": .cgroup_parent,
            "cpuCount": .cpu_count,
            "cpuPercent": .cpu_percent,
            "cpuQuota": .cpuQuota,
            "cpuShares": .cpu_shares,
            "domainName": .domainname,
            "ipcMode": .ipc,
            "memory": .mem_limit,
            "memoryReservation": .mem_reservation,
            "memorySwap": .memswap_limit,
            "memorySwappiness": .mem_swappiness,
            "milliCpuReservation": $milliCpuReservation,
            "oomScoreAdj": .oom_score_adj,
            "pidMode": .pid,
            "pidsLimit": .pids_limit,
            "stopSignal": .stop_signal,
            "stopTimeout": .stop_grace_period,
            "usernsMode": .userns_mode,
            "volumeDriver": .volume_driver,
            "workingDir": .working_dir,
            "labels": (.labels // {"io.rancher.container.pull_image": "always"}),
            "blkioWeight": null,
            "count": .count,
            "cpuPeriod": .cpu_period,
            "cpuRealtimePeriod": null,
            "cpuRealtimeRuntime": null,
            "cpuSet": .cpuset,
            "cpuSetMems": null,
            "dataVolumesFromLaunchConfigs": [],
            "description": .description,
            "devices": (.devices // []),
            "diskQuota": null,
            "dns": (.dns // []),
            "healthInterval": null,
            "healthRetries": null,
            "healthTimeout": null,
            "hostname": .hostname,
            "ioMaximumBandwidth": null,
            "ioMaximumIOps": null,
            "ip": .ip,
            "ip6": .ip6,
            "isolation": .isolation,
            "kernelMemory": null,
            "memoryMb": null,
            "networkLaunchConfig": null,
            "ports": (.ports // []),
            "expose": (.expose // []),
            "requestedIpAddress": null,
            "user": .user,
            "userdata": .userdata,
            "uts": .uts,
            "instanceTriggeredStop": "stop",
            "privileged": (.privileged // false),
            "publishAllPorts": false,
            "secrets": $secrets,
            "system": (.system // false),
            "tty": (.tty // false),
            "vcpu": (.vcpu // 1),
            "environment": (.environment // {}),
            "command": (.command // [])
        }' <<<"$__compose"
    ) || return

    if [[ "$__config_var" ]]; then
        butl.set_var "$__config_var" "$__service_launch_config"
    else
        echo "$__service_launch_config"
    fi
}

rnchr_service_util_reference_secrets() {
    _rnchr_env_args
    barg.arg __compose \
        --required \
        --value=JSON \
        --desc="Compose JSON to work with"
    barg.arg __secrets_var \
        --long=secrets-var \
        --value=VARIABLE \
        --desc="Shell variable to store the secrets array into"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local __compose=
    local __secrets_var=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    # Need to reference secrets by their IDs
    # So we fetch all of them from rancher and match
    local referenced_secrets
    butl.split_lines referenced_secrets "$(jq -Mrc '.secrets[]?' <<<"$__compose")"

    local __secrets='[]'
    if ((${#referenced_secrets[@]})); then
        butl.log_debug "Dereferencing secrets"

        local secrets_json
        _rnchr_pass_env_args rnchr_secret_list --secrets-var secrets_json || return

        local secret
        for secret in "${referenced_secrets[@]}"; do
            local ref_name
            ref_name=$(jq -Mr '.source' <<<"$secret") || return

            local secret_id
            secret_id=$(jq -Mr --arg name "$ref_name" \
                '.[] | select(.name == $name) | .id | select(. != null)' <<<"$secrets_json") || return

            if [[ ! "$secret_id" ]]; then
                : "Cannot retrieve ID for Rancher secret ${BUTL_ANSI_UNDERLINE}$ref_name${BUTL_ANSI_RESET_UNDERLINE}"
                butl.fail "$_"
                return
            fi

            __secrets=$(jq -Mc \
                --argjson secret "$secret" \
                --arg secretId "$secret_id" \
                '. + [(
                    $secret
                    | .type = "secretReference"
                    | .name = .target
                    | .secretId = $secretId
                    | del(.target, .source)
                )]' <<<"$__secrets") || return
        done
    fi

    if [[ "$__secrets_var" ]]; then
        butl.set_var "$__secrets_var" "$__secrets"
    else
        echo "$__secrets"
    fi
}

rnchr_service_util_extract_service_compose() {
    _rnchr_env_args
    barg.arg __compose \
        --required \
        --value=COMPOSE \
        --desc="Stack compose JSON"
    barg.arg __service \
        --required \
        --value=SERVICE \
        --desc="Service to extract from stack compose JSON"
    barg.arg __compose_var \
        --long=compose-var \
        --value=VARIABLE \
        --desc="Shell variable to store the service compose json into"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local __compose=
    local __service=
    local __compose_var=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local __extracted_json
    __extracted_json=$(jq -Mc --arg service "$__service" \
        '.services[$service] | select(. != null)' <<<"$__compose") || return

    if [[ ! "$__extracted_json" ]]; then
        butl.fail "Stack compose file does not contain any definition for service $__service"
        return
    fi

    if [[ "$__compose_var" ]]; then
        butl.set_var "$__compose_var" "$__extracted_json"
    else
        echo "$__extracted_json"
    fi
}

rnchr_service_util_normalize_compose_json() {
    jq -MS "$@" '
        .links = ((.links // []) | sort)
        | .external_links = ((.external_links // []) | sort)
        | .secrets = ((.secrets // []) | sort_by(.target))
        | .ports = ((.ports // []) | sort)
    '
}
