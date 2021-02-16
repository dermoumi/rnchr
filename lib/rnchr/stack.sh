#!/usr/bin/env bash

bgen:import _utils.sh
bgen:import api.sh

rnchr_stack_list() {
    _rnchr_env_args
    barg.arg stacks_var \
        --long=stacks-var \
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

    local stacks_var=

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
        "stacks" --get \
        --data-urlencode "limit=-1" || return

    local __stacks_list
    __stacks_list=$(jq -Mc '.data' <<<"$_response")

    if [[ "$stacks_var" ]]; then
        butl.set_var "$stacks_var" "$__stacks_list"
    else
        echo "$__stacks_list"
    fi
}

rnchr_stack_get() {
    _rnchr_env_args
    barg.arg name \
        --required \
        --value=STACK \
        --desc="Stack to inspect"
    barg.arg stack_var \
        --long=stack-var \
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
    local stack_var=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local query=
    if [[ "$name" =~ ^1st[[:digit:]]+ ]]; then
        query="id=${name#1st}"
    else
        query="name=$name"
    fi

    local response=
    _rnchr_pass_env_args rnchr_env_api \
        --response-var response \
        "stacks" --get \
        --data-urlencode "$query" \
        --data-urlencode "limit=-1" || return

    if [[ "$response" && "$(jq -Mr '.data | length' <<<"$response")" -gt 0 ]]; then
        local __stack_json
        __stack_json=$(jq -Mc '.data[0] | select(. != null)' <<<"$response") || return

        if [[ "$__stack_json" ]]; then
            if [[ "$stack_var" ]]; then
                butl.set_var "$stack_var" "$__stack_json"
            else
                echo "$__stack_json"
            fi

            return
        fi
    fi

    butl.fail "Stack ${BUTL_ANSI_UNDERLINE}$name${BUTL_ANSI_RESET_UNDERLINE} not found"
}

rnchr_stack_get_services() {
    _rnchr_env_args
    barg.arg name \
        --required \
        --value=STACK \
        --desc="Stack to get the services of"
    barg.arg services_var \
        --long=services-var \
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
    local services_var=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local _stack_id=
    _rnchr_pass_env_args rnchr_stack_get_id --id-var _stack_id "$name" || return

    local response=
    _rnchr_pass_env_args rnchr_env_api \
        --response-var response \
        "stacks/$_stack_id/services" || return

    response=$(jq -Mc '.data | select(. != null)' <<<"$response") || return

    if [[ ! "$response" ]]; then
        response="[]"
    fi

    if [[ "$services_var" ]]; then
        butl.set_var "$services_var" "$response"
    else
        echo "$response"
    fi
}

rnchr_stack_get_containers() {
    _rnchr_env_args
    barg.arg name \
        --required \
        --value=STACK \
        --desc="Stack to get the services of"
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

    local name=
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

    # If we have a stack ID, query the stack name
    if [[ "$name" =~ ^1st[[:digit:]]+ ]]; then
        local stack=
        _rnchr_pass_env_args rnchr_stack_get --stack-var stack "$name" || return

        name=$(jq -Mr '.name' <<<"$stack") || return
    fi

    local _args=()
    if ((all_containers)); then
        _args+=(--all)
    fi
    if ((all_running)); then
        _args+=(--running)
    fi

    local _stack_containers=
    _rnchr_pass_env_args rnchr_container_list --containers-var _stack_containers "${_args[@]}" || return

    _stack_containers=$(jq -Mc --arg stack "$name" \
        '[ .[] | select(.labels["io.rancher.stack.name"] == $stack) ]' <<<"$_stack_containers") || return

    if [[ "$containers_var" ]]; then
        butl.set_var "$containers_var" "$_stack_containers"
    else
        echo "$_stack_containers"
    fi
}

rnchr_stack_get_id() {
    _rnchr_env_args
    barg.arg _stack \
        --required \
        --value=STACK \
        --desc="Stack to inspect"
    barg.arg _stack_id_var \
        --long=id-var \
        --value=VARIABLE \
        --desc="Shell variable to store the ID in"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local _stack=
    local _stack_id_var=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    # If we have a stack ID, query the stack name
    local __stack_id=
    if [[ "$_stack" =~ ^1st[[:digit:]]+ ]]; then
        __stack_id=$_stack
    else
        local _stack_json=
        _rnchr_pass_env_args rnchr_stack_get --stack-var _stack_json "$_stack" || return

        __stack_id=$(jq -Mr '.id' <<<"$_stack_json") || return
    fi

    if [[ "$_stack_id_var" ]]; then
        butl.set_var "$_stack_id_var" "$__stack_id"
    else
        echo "$__stack_id"
    fi
}

rnchr_stack_get_config() {
    _rnchr_env_args
    barg.arg _stack \
        --required \
        --value=STACK \
        --desc="Stack to inspect"
    barg.arg _dcompose_var \
        --long=dcompose-var \
        --value=VARIABLE \
        --desc="Shell variable to store docker-compose file in"
    barg.arg _rcompose_var \
        --long=rcompose-var \
        --value=VARIABLE \
        --desc="Shell variable to store rancher-compose file in"
    barg.arg _dcompose_file \
        --long=dcompose \
        --value=FILENAME \
        --desc="Filename to store docker-compose file as"
    barg.arg _rcompose_file \
        --long=rcompose \
        --value=FILENAME \
        --desc="Filename to store rancher-compose file as"
    barg.arg _to_json \
        --long=json \
        --desc="If set, retrieves compose files as json"
    barg.arg _merged_json_var \
        --long=merged-json-var \
        --value=VARIABLE \
        --desc="Shell variable to store the merged compose files in"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local _stack=
    local _dcompose_var=
    local _rcompose_var=
    local _dcompose_file=
    local _rcompose_file=
    local _to_json=
    local _merged_json_var=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    if [[ ! "$_merged_json_var$_dcompose_var$_rcompose_var$_dcompose_file$_rcompose_file" ]]; then
        : "You should specify at least one of the following options:\n"
        butl.fail "$_ --dcompose, --dcompose-var, --rcompose, --rcompose-var, --merged-json-var"
        return
    fi

    local _stack_id=
    _rnchr_pass_env_args rnchr_stack_get_id --id-var _stack_id "$_stack" || return

    local _stack_config_json=
    _rnchr_pass_env_args rnchr_env_api \
        --response-var _stack_config_json \
        "stacks/$_stack_id/?action=exportconfig" \
        -X POST || return

    local _dcompose_content _rcompose_content
    _dcompose_content=$(jq -Mr '.dockerComposeConfig' <<<"$_stack_config_json") || return
    _rcompose_content=$(jq -Mr '.rancherComposeConfig' <<<"$_stack_config_json") || return

    if ((_to_json)); then
        _dcompose_content=$(rnchr_util_yaml_to_json <<<"$_dcompose_content") || return
        _rcompose_content=$(rnchr_util_yaml_to_json <<<"$_rcompose_content") || return
    fi

    if [[ "$_dcompose_var" ]]; then
        butl.set_var "$_dcompose_var" "$_dcompose_content"
    fi

    if [[ "$_rcompose_var" ]]; then
        butl.set_var "$_rcompose_var" "$_rcompose_content"
    fi

    if [[ "$_dcompose_file" ]]; then
        printf '%s' "$_dcompose_content" >"$_dcompose_file"
    fi

    if [[ "$_rcompose_file" ]]; then
        printf '%s' "$_rcompose_content" >"$_rcompose_file"
    fi

    if [[ "$_merged_json_var" ]]; then
        local _dcompose_json _rcompose_json
        if ((_to_json)); then
            _dcompose_json=$_dcompose_content
            _rcompose_json=$_rcompose_content
        else
            _dcompose_json=$(rnchr_util_yaml_to_json <<<"$_dcompose_content") || return
            _rcompose_json=$(rnchr_util_yaml_to_json <<<"$_rcompose_content") || return
        fi

        local __merged_json=
        __merged_json=$(jq -Mc --argjson rcompose "$_rcompose_json" '$rcompose * .' <<<"$_dcompose_json")

        butl.set_var "$_merged_json_var" "$__merged_json"
    fi
}

rnchr_stack_stop() {
    _rnchr_env_args
    barg.arg name \
        --required \
        --value=STACK \
        --desc="Stack to inspect"
    barg.arg await \
        --short=w \
        --long=wait \
        --desc="Wait until all containers of the stack have stopped"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local name=
    local await=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local stack_name=
    local stack_id=
    if [[ "$name" =~ ^1st[[:digit:]]+ ]]; then
        stack_id=$name

        # We only need to fetch the stack name if we're going to have to wait for stack containers to stop
        if ((await)); then
            local stack=
            _rnchr_pass_env_args rnchr_stack_get --stack-var stack "$name" || return

            stack_name=$(jq -Mrc '.name' <<<"$stack") || return
        fi
    else
        local stack=
        _rnchr_pass_env_args rnchr_stack_get --stack-var stack "$name" || return

        stack_id=$(jq -Mrc '.id' <<<"$stack") || return
        stack_name=$name
    fi

    butl.muffle_all _rnchr_pass_env_args rnchr_env_api \
        "stacks/$stack_id/?action=deactivateservices" -X POST || return

    if ((await)); then
        rnchr_stack_wait_for_containers_to_stop "$stack_name"
    fi
}

rnchr_stack_remove() {
    _rnchr_env_args
    barg.arg name \
        --required \
        --value=STACK \
        --desc="Stack to inspect"
    barg.arg await \
        --short=w \
        --long=wait \
        --desc="Wait until all containers of the stack have stopped"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local name=
    local await=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local stack_name=
    local stack_id=
    if [[ "$name" =~ ^1st[[:digit:]]+ ]]; then
        stack_id=$name

        # We only need to fetch the stack name if we're going to have to wait for stack containers to stop
        if ((await)); then
            local stack=
            _rnchr_pass_env_args rnchr_stack_get --stack-var stack "$name" || return

            stack_name=$(jq -Mrc '.name' <<<"$stack") || return
        fi
    else
        local stack=
        _rnchr_pass_env_args rnchr_stack_get --stack-var stack "$name" || return

        stack_id=$(jq -Mrc '.id' <<<"$stack") || return
        stack_name=$name
    fi

    butl.muffle_all _rnchr_pass_env_args rnchr_env_api \
        "stacks/$stack_id" -X DELETE || return

    if ((await)); then
        rnchr_stack_wait_for_containers_to_stop "$stack_name"
    fi
}

rnchr_stack_exists() {
    _rnchr_env_args
    barg.arg name \
        --required \
        --value=STACK \
        --desc="Stack to inspect"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
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
    if [[ "$name" =~ ^1st[[:digit:]]+ ]]; then
        query="id=${name#1st}"
    else
        query="name=$name"
    fi

    local response=
    _rnchr_pass_env_args rnchr_env_api \
        --response-var response \
        "stacks" --get --data-urlencode "$query" || return

    [[ "$response" && "$(jq -Mr '.data[0] | select(. != null)' <<<"$response")" ]]
}

rnchr_stack_wait_for_containers_to_stop() {
    local stack_name=$1

    if [[ "$stack_name" =~ ^1st[[:digit:]]+ ]]; then
        : "Called rnchr_stack_wait_for_containers_to_stop using a stack ID."
        butl.log_warning "$_ Please use a stack name for reliable results"
    fi

    # Wait for all services to reach our desired state
    butl.log_debug "Waiting for containers of stack $stack_name to stop..."

    while [[ "$(rnchr_stack_get_containers "$stack_name" --running | jq -Mrc '.[]')" ]]; do
        sleep 1
    done
}

rnchr_stack_update_meta() {
    _rnchr_env_args
    barg.arg stack \
        --required \
        --value=STACK \
        --desc="Stack to inspect"
    barg.arg name \
        --value=NAME \
        --long=name \
        --short=n \
        --desc="New name to set for the stack"
    barg.arg desc \
        --value=DESCRIPTION \
        --long=desc \
        --short=d \
        --desc="New description to set for the stack"
    barg.arg tags \
        --value=TAGS \
        --long=tags \
        --short=t \
        --desc="Comma separated tags to set for the stack"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local stack=
    local name="__RNCHR_STACK_DEFAULT_NAME"
    local desc="__RNCHR_STACK_DEFAULT_DESCRIPTION"
    local tags="__RNCHR_STACK_DEFAULT_TAG"

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local _stack_id=
    _rnchr_pass_env_args rnchr_stack_get_id --id-var _stack_id "$stack" || return

    local payload="{}"
    if [[ "$name" != "__RNCHR_STACK_DEFAULT_NAME" ]]; then
        payload=$(jq --arg name "$name" -Mc '.name = $name' <<<"$payload")
    fi
    if [[ "$desc" != "__RNCHR_STACK_DEFAULT_DESCRIPTION" ]]; then
        payload=$(jq --arg desc "$desc" -Mc '.description = $desc' <<<"$payload")
    fi
    if [[ "$tags" != "__RNCHR_STACK_DEFAULT_TAG" ]]; then
        payload=$(jq --arg tags "$tags" -Mc '.group = $tags' <<<"$payload")
    fi
    if [[ "$payload" == "{}" ]]; then
        butl.fail "No changes to apply"
        return
    fi

    butl.muffle_all _rnchr_pass_env_args rnchr_env_api \
        "stacks/$_stack_id" -X PUT -d "$payload" || return
}

rnchr_stack_wait_for_service_action() {
    _rnchr_env_args
    barg.arg stack \
        --required \
        --value=STACK \
        --desc="Stack name"
    barg.arg action \
        --required \
        --value=ACTION \
        --desc="Action to wait for for"
    barg.arg services \
        --multi \
        --value=SERVICE \
        --desc="Service to watch for"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local stack=
    local action=
    local services=()

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    butl.log_debug "Waiting for services to have action $action: ${services[*]/#/$stack}"

    local service_count=${#services[@]}
    if ((service_count == 1)); then
        local service=${services[0]}
        _rnchr_pass_env_args rnchr_service_wait_for_action "$stack/$service" "$action" || return
    elif ((service_count > 1)); then
        while true; do
            local services_json=
            _rnchr_pass_env_args rnchr_stack_get_services --services-var services_json "$stack" || return

            local service
            local failed=0
            for service in "${services[@]}"; do
                local service_json=
                service_json=$(jq -Mc --arg service "$service" \
                    '.[] | select(.name == $service)' <<<"$services_json") || return

                if [[ ! "$service_json" ]]; then
                    butl.fail "Service $stack/$service not found"
                    return
                fi

                local endpoint=
                endpoint=$(jq -Mr --arg action "$action" \
                    '.actions[$action] | select(. != null)' <<<"$service_json") || return

                # If endpoint is available, print it and break from loop
                if [[ ! "$endpoint" ]]; then
                    failed=1
                fi
            done

            if ! ((failed)); then
                break
            fi

            # Wait for 1 seconds before trying again
            sleep 1
        done
    fi
}

rnchr_stack_make_services_upgradable() {
    _rnchr_env_args
    barg.arg stack \
        --required \
        --value=STACK \
        --desc="Stack name"
    barg.arg services \
        --multi \
        --value=SERVICE \
        --desc="Service to watch for"
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

    local stack=
    local services=()
    local await=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local service_count=${#services[@]}
    if ! ((service_count)); then
        local stack_services
        _rnchr_pass_env_args rnchr_stack_get_services "$stack" --services-var stack_services || return

        local services_lines
        services_lines=$(jq -Mr '.[] | .name' <<<"$stack_services") || return

        if [[ ! "$services_lines" ]]; then
            return
        fi

        butl.split_lines services "$services_lines"
    fi

    if ((service_count == 1)); then
        local service=${services[0]}

        if ((await)); then
            local args="--wait"
        else
            local args=''
        fi

        # shellcheck disable=SC2086
        _rnchr_pass_env_args rnchr_service_make_upgradable "$stack/$service" $args || return
    else
        local stack_services
        _rnchr_pass_env_args rnchr_stack_get_services "$stack" --services-var stack_services || return

        local services_awaiting=()
        local service
        for service in "${services[@]}"; do
            butl.log_debug "Making $stack/$service reach an upgradable state"

            local service_json=
            service_json=$(jq -Mc --arg service "$service" \
                '.[] | select(.name == $service)' <<<"$stack_services") || return

            if [[ ! "$service_json" ]]; then
                butl.fail "Service $stack/$service does not exist"
                return
            fi

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
                services_awaiting+=("$service")
            fi
        done

        if ((${#services_awaiting[@]})) && ((await)); then
            _rnchr_pass_env_args rnchr_stack_wait_for_service_action \
                "$stack" upgrade "${services_awaiting[@]}" || return
        fi
    fi
}

rnchr_stack_remove_non_upgradable_services() {
    _rnchr_env_args
    barg.arg stack \
        --required \
        --value=STACK \
        --desc="Stack name"
    barg.arg services \
        --multi \
        --value=SERVICE \
        --desc="Service to watch for"
    barg.arg await \
        --short=w \
        --long=wait \
        --desc="Wait until the service containers have been stopped"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local stack=
    local services=()
    local await=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    butl.log_info "Removing services in non-upgrabale states from stack $stack"

    local service_json
    local service_id

    local stack_services
    _rnchr_pass_env_args rnchr_stack_get_services "$stack" --services-var stack_services || return

    local target_services=()
    if ((${#services[@]})); then
        for service in "${services[@]}"; do
            service_json=$(jq -Mc --arg service "$service" '.[$service]' <<<"$stack_services") || return

            target_services+=("$service_json")
        done
    else
        butl.split_lines target_services "$(jq -Mc '.[]' <<<"$stack_services")" || return
    fi

    local non_upgradable_services=()
    for service_json in "${target_services[@]}"; do
        local upgrade_link
        upgrade_link=$(jq -Mr '.actions.upgrade | select(. != null)' <<<"$service_json") || continue

        if [[ ! "$upgrade_link" ]]; then
            service_id=$(jq -Mr '.id' <<<"$service_json") || return

            local service_name
            service_name=$(jq -Mr '.name' <<<"$service_json") || return

            butl.log_info "Removing $service_name..."
            _rnchr_pass_env_args rnchr_service_remove "$service_id" || continue

            non_upgradable_services+=("$service_id")
        fi
    done

    if ((${#non_upgradable_services[@]})) && ((await)); then
        for service_id in "${non_upgradable_services[@]}"; do
            _rnchr_pass_env_args rnchr_service_wait_for_containers_to_stop "$service_id" || continue
        done
    fi
}

rnchr_stack_upgrade_services() {
    _rnchr_env_args
    barg.arg stack \
        --required \
        --value=STACK \
        --desc="Stack name"
    barg.arg services \
        --multi \
        --value=SERVICE \
        --desc="Service to watch for"
    barg.arg compose_json \
        --long=compose-json \
        --value=JSON \
        --desc="Stack compose JSON"
    barg.arg finish_upgrade \
        --long=finish-upgrade \
        --desc="Finishes upgrade"
    barg.arg finish_upgrade_timeout \
        --implies=finish_upgrade \
        --long=finish-upgrade-timeout \
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

    local stack=
    local services=()
    local compose_json=
    local finish_upgrade=
    local finish_upgrade_timeout=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    if ((${#services[@]} == 0)); then
        local services_lines
        services_lines=$(jq -Mr '.services | to_entries[] | .key' <<<"$compose_json") || return

        if [[ ! "$services_lines" ]]; then
            return
        fi

        butl.split_lines services "$services_lines"
    fi

    butl.log_info "Upgrading $stack services: $(butl.join_by ' ' "${services[@]}")"

    local stack_services
    _rnchr_pass_env_args rnchr_stack_get_services "$stack" --services-var stack_services || return

    local service
    local service_id
    local service_ids=()
    local co_run_commands=()
    for service in "${services[@]}"; do
        local service_id
        service_id=$(jq -Mr --arg name "$service" '.[] | select(.name == $name) | .id' <<<"$stack_services") || return

        if [[ ! "$service_id" ]]; then
            butl.fail "Service $stack/$service does not exist"
            return
        fi
        service_ids+=("$service_id")

        local service_compose
        _rnchr_pass_env_args rnchr_service_util_extract_service_compose \
            "$compose_json" "$service" --compose-var service_compose || return

        co_run_commands+=("$(
            printf '%q ' _rnchr_pass_env_args rnchr_service_upgrade "$service_id" \
                --service-compose-json "$service_compose"
        )")
    done

    # shellcheck disable=SC2034
    local result=()

    butl.co_run result "${co_run_commands[@]}" || return

    if ((finish_upgrade)); then
        co_run_commands=()
        for service_id in "${service_ids[@]}"; do
            co_run_commands+=("$(
                printf '%q ' _rnchr_pass_env_args rnchr_service_finish_upgrade "$service_id" \
                    --timeout="$finish_upgrade_timeout"
            )")
        done

        butl.co_run result "${co_run_commands[@]}" || return
    fi
}

rnchr_stack_ensure_secrets_mounted() {
    _rnchr_env_args
    barg.arg stack \
        --required \
        --value=STACK \
        --desc="Stack name"
    barg.arg services \
        --multi \
        --value=SERVICE \
        --desc="Service to watch for"
    barg.arg compose_json \
        --long=compose-json \
        --value=JSON \
        --desc="Stack compose JSON"
    barg.arg finish_upgrade_timeout \
        --long=finish-upgrade-timeout \
        --value=SECONDS \
        --desc="Finishes upgrade but fails if exceeds given time"
    barg.arg no_fix \
        --long=no-fix \
        --desc="Do not attempt to fix the service"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local stack=
    local services=()
    local compose_json=
    local finish_upgrade_timeout=
    local no_fix=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local concerned_services=
    if ((${#services[@]})); then
        concerned_services=("${services[@]}")
    else
        butl.split_lines concerned_services "$(jq -Mrc '.services | to_entries[]
            | select(.value.secrets | length > 0) | .key' <<<"$compose_json")" || return
    fi

    # preload rancher env ID before running co_run
    _rnchr_pass_args rnchr_env_get_id "${RANCHER_ENVIRONMENT:-}" >/dev/null || return

    local affected_services=()
    local service=

    if ((${#concerned_services[@]} == 1)); then
        service="${concerned_services[0]}"
        if ! _rnchr_pass_env_args rnchr_service_ensure_secrets_mounted "$stack/$service" --no-fix; then
            affected_services+=("$service")
        fi
    elif ((${#concerned_services[@]} > 0)); then
        local args=()
        for service in "${concerned_services[@]}"; do
            butl.log_info "Checking $service..."

            : "_rnchr_pass_env_args rnchr_service_ensure_secrets_mounted"
            args+=("$_ '$stack/$service' --no-fix || echo '$service'")
        done

        local result=()
        butl.co_run result "${args[@]}" || return

        if ((${#result[@]})); then
            for service in "${result[@]}"; do
                if [[ "$service" ]]; then
                    affected_services+=("$service")
                fi
            done
        fi
    fi

    if ((${#affected_services[@]})); then
        if ((no_fix)); then
            : "$(butl.join_by ', ' "${affected_services[@]}")"
            butl.log_error "Stack $stack has services with no secrets mounted: $_"
            return 1
        fi

        : "$(butl.join_by ', ' "${affected_services[@]}")"
        butl.log_error "Stack $stack has services with no secrets mounted: $_, re-deploying..."

        _rnchr_pass_env_args rnchr_stack_upgrade_services "$stack" --compose-json "$compose_json" \
            "${affected_services[@]}" --finish-upgrade --finish-upgrade-timeout="$finish_upgrade_timeout" || return

        _rnchr_pass_env_args rnchr_stack_make_services_upgradable "$stack" "${affected_services[@]}" || return

        _rnchr_pass_env_args rnchr_stack_ensure_secrets_mounted "$stack" --compose-json "$compose_json" \
            "${affected_services[@]}" || return
    fi
}
