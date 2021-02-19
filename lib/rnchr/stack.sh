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
        --data-urlencode "removed_null=1" \
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
    barg.arg _use_stack_list \
        --hidden \
        --long=use-stack-list \
        --value=JSON

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
    local _use_stack_list=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local __list_stack=

    if [[ "$_use_stack_list" ]]; then
        if [[ "$name" =~ ^1st[[:digit:]]+ ]]; then
            __list_stack=$(jq -Mc --arg id "$name" '.[] | select(.id == $id)' <<<"$_use_stack_list") || return
        else
            __list_stack=$(jq -Mc --arg name "$name" '.[] | select(.name == $name)' <<<"$_use_stack_list") || return
        fi
    else
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
            --data-urlencode "removed_null=1" \
            --data-urlencode "limit=-1" || return

        if [[ "$response" && "$(jq -Mr '.data | length' <<<"$response")" -gt 0 ]]; then
            local __list_stack
            __list_stack=$(jq -Mc '.data[0] | select(. != null)' <<<"$response") || return
        fi
    fi

    if [[ "$__list_stack" ]]; then
        if [[ "$stack_var" ]]; then
            butl.set_var "$stack_var" "$__list_stack"
        else
            echo "$__list_stack"
        fi

        return
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
    barg.arg _use_stack_list \
        --hidden \
        --long=use-stack-list \
        --value=JSON

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
    local _use_stack_list=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local _stack_id=
    _rnchr_pass_env_args rnchr_stack_get_id --id-var _stack_id --use-stack-list "$_use_stack_list" "$name" || return

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
    barg.arg _use_stack_list \
        --hidden \
        --long=use-stack-list \
        --value=JSON

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
    local _use_stack_list=

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
        _rnchr_pass_env_args rnchr_stack_get "$_stack" \
            --use-stack-list "$_use_stack_list" --stack-var _stack_json || return

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
    barg.arg __stack \
        --required \
        --value=STACK \
        --desc="Stack to inspect"
    barg.arg __stack_var \
        --long=stack-var \
        --value=VARIABLE \
        --desc="Shell variable to store the stack json in"
    barg.arg __id_var \
        --long=id-var \
        --value=VARIABLE \
        --desc="Shell variable to store the stack id in"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local __stack=
    local __stack_var=
    local __id_var=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local __query=
    if [[ "$__stack" =~ ^1st[[:digit:]]+ ]]; then
        __query="id=${__stack#1st}"
    else
        __query="name=$__stack"
    fi

    local __response=
    _rnchr_pass_env_args rnchr_env_api \
        --response-var __response \
        "stacks" --get \
        --data-urlencode "removed_null=1" \
        --data-urlencode "$__query" || return

    local __stack_json=
    __stack_json=$(jq -Mc '.data[0] | select(. != null)' <<<"$__response") || return

    if [[ ! "$__stack_json" ]]; then
        return 1
    fi

    if [[ "$__stack_var" ]]; then
        butl.set_var "$__stack_var" "$__stack_json"
    fi

    if [[ "$__id_var" ]]; then
        local __stack_id
        __stack_id=$(jq -Mr '.id' <<<"$__stack_json") || return

        butl.set_var "$__id_var" "$__stack_id"
    fi
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

rnchr_stack_create() {
    _rnchr_env_args
    barg.arg __stack \
        --required \
        --value=NAME \
        --desc="Stack name"
    barg.arg __desc \
        --value=DESCRIPTION \
        --long=desc \
        --short=d \
        --desc="New description to set for the stack"
    barg.arg __tags \
        --value=TAGS \
        --long=tags \
        --short=t \
        --desc="Comma separated tags to set for the stack"
    barg.arg __id_var \
        --implies=__silent \
        --value=VARIABLE \
        --long=id-var \
        --desc="Shell variable to store the stack ID"
    barg.arg __stack_var \
        --implies=__silent \
        --value=VARIABLE \
        --long=stack-var \
        --desc="Shell variable to store the stack JSON"
    barg.arg __silent \
        --long=silent \
        --short=s \
        --desc="Do not output stack JSON after creation"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local __stack=
    local __desc="__RNCHR_STACK_DEFAULT_DESCRIPTION"
    local __tags="__RNCHR_STACK_DEFAULT_TAG"
    local __id_var=
    local __stack_var=
    local __silent=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local payload=
    payload=$(jq -Mnc --arg name "$__stack" '{"name": $name}')

    if [[ "$__desc" != "__RNCHR_STACK_DEFAULT_DESCRIPTION" ]]; then
        payload=$(jq -Mc --arg desc "$__desc" '.description = $desc' <<<"$payload")
    fi

    if [[ "$__tags" != "__RNCHR_STACK_DEFAULT_TAG" ]]; then
        payload=$(jq -Mc --arg tags "$__tags" '.group = $tags' <<<"$payload")
    fi

    local __response=
    _rnchr_pass_env_args rnchr_env_api --response-var __response \
        "stacks" -X POST -d "$payload" || return

    if [[ "$__id_var" ]]; then
        local __stack_id
        __stack_id=$(jq -Mr '.id' <<<"$__response")

        butl.set_var "$__id_var" "$__stack_id"
    fi

    if [[ "$__stack_var" ]]; then
        butl.set_var "$__stack_var" "$__response"
    elif ! ((__silent)); then
        echo "$__response"
    fi
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
    barg.arg _use_stack_json \
        --hidden \
        --value=JSON \
        --long=use-stack-json

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
    local _use_stack_json=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local stack_json=
    if [[ "$_use_stack_json" ]]; then
        stack_json=$_use_stack_json
    else
        _rnchr_pass_env_args rnchr_stack_get --stack-var stack_json "$stack" || return
    fi

    local stack_id=
    stack_id=$(jq -Mr '.id' <<<"$stack_json") || return

    local payload="{}"

    if [[ "$name" != "__RNCHR_STACK_DEFAULT_NAME" ]]; then
        local remote_name
        remote_name="$(jq -Mr '.name' <<<"$stack_json")" || return

        if [[ "$name" != "$remote_name" ]]; then
            payload=$(jq -Mc --arg name "$name" '.name = $name' <<<"$payload")
        fi
    fi

    if [[ "$desc" != "__RNCHR_STACK_DEFAULT_DESCRIPTION" ]]; then
        local remote_desc
        remote_desc="$(jq -Mr '.description' <<<"$stack_json")" || return

        if [[ "$desc" != "$remote_desc" ]]; then
            payload=$(jq -Mc --arg desc "$desc" '.description = $desc' <<<"$payload")
        fi
    fi

    if [[ "$tags" != "__RNCHR_STACK_DEFAULT_TAG" ]]; then
        local remote_tags
        remote_tags="$(jq -Mr '.group' <<<"$stack_json")" || return

        if [[ "$tags" != "$remote_tags" ]]; then
            payload=$(jq -Mc --arg tags "$tags" '.group = $tags' <<<"$payload")
        fi
    fi

    if [[ "$payload" == "{}" ]]; then
        return
    fi

    butl.muffle_all _rnchr_pass_env_args rnchr_env_api \
        "stacks/$stack_id" -X PUT -d "$payload" || return
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

    local stack_services
    _rnchr_pass_env_args rnchr_stack_get_services "$stack" --services-var stack_services || return

    local service_count=${#services[@]}
    if ! ((service_count)); then

        local services_lines
        services_lines=$(jq -Mr '.[] | .name' <<<"$stack_services") || return

        if [[ ! "$services_lines" ]]; then
            return
        fi

        butl.split_lines services "$services_lines"
    fi

    butl.log_debug "Making $stack services reach an upgradable state: ${services[*]}"

    if ((service_count == 1)); then
        local service=${services[0]}
        local args=("$stack/$service")

        if ((await)); then
            args+=(--wait)
        fi

        _rnchr_pass_env_args rnchr_service_make_upgradable "${args[@]}" || return
    else
        local co_run_commands=()

        local services_awaiting=()
        local service
        for service in "${services[@]}"; do
            local service_json=
            service_json=$(jq -Mc --arg service "$service" \
                '.[] | select(.name == $service)' <<<"$stack_services") || return

            if [[ ! "$service_json" ]]; then
                butl.fail "Service $stack/$service does not exist"
                return
            fi

            local service_id=
            service_id=$(jq -Mr '.id' <<<"$service_json") || return

            co_run_commands+=(
                "$(printf -- '%q ' _rnchr_pass_env_args rnchr_service_make_upgradable "$service_id" \
                    --use-service "$service_json")"
            )
        done

        if ! ((${#co_run_commands[@]})); then
            return
        fi

        butl.co_run "" "${co_run_commands[@]}" || return

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

rnchr_stack_finish_upgrade() {
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

    local stack_id=
    _rnchr_pass_env_args rnchr_stack_get_id "$stack" --id-var stack_id || return

    local stack_services
    _rnchr_pass_env_args rnchr_stack_get_services "$stack_id" --services-var stack_services || return

    local service_count=${#services[@]}
    if ! ((service_count)); then
        local services_lines
        services_lines=$(jq -Mr '.[] | .name' <<<"$stack_services") || return

        if [[ ! "$services_lines" ]]; then
            return
        fi

        butl.split_lines services "$services_lines"
    fi

    butl.log_debug "Making $stack services reach an upgradable state: ${services[*]}"

    if ((service_count == 1)); then
        local service=${services[0]}
        local args=("$stack_id/$service" --use-service-list "$stack_services")
        echo "$stack_id/$service" >&2

        if ((await)); then
            args+=(--wait)
        fi

        _rnchr_pass_env_args rnchr_service_finish_upgrade "${args[@]}" || return
    else
        local co_run_commands=()

        local service
        for service in "${services[@]}"; do
            local args=(
                "\"\$stack_id/$service\""
                --use-service-list
                "\"\$stack_services\""
            )

            if ((await)); then
                args+=(--wait)
            fi

            co_run_commands+=("_rnchr_pass_env_args rnchr_service_finish_upgrade ${args[*]}")
        done

        if ! ((${#co_run_commands[@]})); then
            return
        fi

        butl.co_run "" "${co_run_commands[@]}" || return
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

    local stack_id=
    _rnchr_pass_env_args rnchr_stack_get_id --id-var stack_id "$stack" || return

    if [[ ! "$compose_json" ]]; then
        _rnchr_pass_env_args rnchr_stack_get_config "$stack_id" --merged-json-var compose_json || return
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
    _rnchr_pass_env_args rnchr_stack_get_services "$stack_id" --services-var stack_services || return

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
        butl.log_error "Stack $stack has services with no secrets mounted: $_. Re-deploying..."

        _rnchr_pass_env_args rnchr_stack_upgrade_services "$stack" --compose-json "$compose_json" \
            "${affected_services[@]}" --finish-upgrade --finish-upgrade-timeout="$finish_upgrade_timeout" || return

        _rnchr_pass_env_args rnchr_stack_make_services_upgradable "$stack" "${affected_services[@]}" || return

        _rnchr_pass_env_args rnchr_stack_ensure_secrets_mounted "$stack" --compose-json "$compose_json" \
            "${affected_services[@]}" || return
    fi
}

rnchr_stack_up() {
    _rnchr_env_args
    barg.arg stack \
        --required \
        --value=NAME \
        --desc="Stack name"
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

    barg.arg services \
        --multi \
        --value=SERVICE \
        --desc="Service to upgrade if already exist"
    barg.arg compose_json \
        --long=compose-json \
        --value=JSON \
        --desc="Stack compose JSON"
    barg.arg upgrade \
        --long=upgrade \
        --desc="Also upgrade existing services"
    barg.arg force_upgrade \
        --implies=upgrade \
        --long=force-upgrade \
        --desc="Upgrade even if existing service is up to date"
    barg.arg no_create \
        --long=no-create \
        --desc="Don't create stack or services if they don't exist"
    barg.arg no_update_links \
        --long=no-update-links \
        --desc="Don't update service links"
    barg.arg no_finish_upgrade \
        --long=no-finish-upgrade \
        --desc="Don't finishe upgrade"
    barg.arg finish_upgrade_timeout \
        --long=finish-upgrade-timeout \
        --value=SECONDS \
        --desc="Finishes upgrade but fails if exceeds given time"

    barg.arg await \
        --long=wait \
        --short=w \
        --desc="Wait until all operations have finished"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local stack=
    local desc="__RNCHR_STACK_DEFAULT_DESCRIPTION"
    local tags="__RNCHR_STACK_DEFAULT_TAG"

    local services=()
    local compose_json=
    local upgrade=
    local force_upgrade=
    local no_create=
    local no_update_links=
    local no_finish_upgrade=
    local finish_upgrade_timeout=

    local await=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local meta_args=()
    if [[ "$desc" != "__RNCHR_STACK_DEFAULT_DESCRIPTION" ]]; then
        meta_args+=(--desc "$desc")
    fi
    if [[ "$tags" != "__RNCHR_STACK_DEFAULT_TAG" ]]; then
        meta_args+=(--tags "$tags")
    fi

    local stack_id=
    local stack_json=

    local service
    local create_services=()
    local upgrade_services=()
    local recreate_services=()

    local stack_service_lines
    stack_service_lines=$(jq -Mr '.services | keys[]' <<<"$compose_json") || return

    local all_compose_services=()
    butl.split_lines all_compose_services "${stack_service_lines[@]}"

    local compose_services=()
    for service in "${all_compose_services[@]}"; do
        if ! ((${#services[@]})) || [[ " ${services[*]} " == *" $service "* ]]; then
            compose_services+=("$service")
        fi
    done

    if _rnchr_pass_env_args rnchr_stack_exists "$stack" --id-var stack_id --stack-var stack_json; then
        if ((upgrade)) && ((${#meta_args[@]})); then
            _rnchr_pass_env_args rnchr_stack_update_meta --use-stack-json "$stack_json" \
                "$stack_id" "${meta_args[@]}" || return
        fi

        local remote_compose_json=
        _rnchr_pass_env_args rnchr_stack_get_config "$stack_id" --merged-json-var remote_compose_json || return

        for service in "${compose_services[@]}"; do
            local remote_service_compose
            remote_service_compose=$(jq -Mc --arg service "$service" \
                '.services[$service] | select(. != null)' <<<"$remote_compose_json")

            if [[ ! "$remote_service_compose" ]]; then
                create_services+=("$service")
            elif ((upgrade)); then
                local service_compose
                _rnchr_pass_env_args rnchr_service_util_extract_service_compose \
                    "$compose_json" "$service" --compose-var service_compose || return

                local remote_is_builtin_service=0
                local remote_image=
                local remote_cmp_compose=
                remote_cmp_compose=$(
                    rnchr_service_util_normalize_compose_json \
                        remote_is_builtin_service \
                        remote_image \
                        <<<"$remote_service_compose"
                ) || return

                local is_builtin_service=0
                local service_image=
                local service_cmp_compose=
                service_cmp_compose=$(
                    rnchr_service_util_normalize_compose_json \
                        is_builtin_service \
                        service_image \
                        <<<"$service_compose"
                ) || return

                if [[ "$remote_image" != "$service_image" ]] \
                    && ((remote_is_builtin_service || is_builtin_service)); then
                    recreate_services+=("$service")
                elif ((force_upgrade)); then
                    upgrade_services+=("$service")
                elif ! cmp <(echo "$remote_cmp_compose") <(echo "$service_cmp_compose") >/dev/null; then
                    upgrade_services+=("$service")

                    if ((${LOG_LEVEL:-5} >= 7)); then
                        butl.log_debug "Adding $service to upgrade queue:"
                        butl.log_debug "$(
                            diff <(echo "$remote_cmp_compose") <(echo "$service_cmp_compose")
                        )" || true
                    fi
                fi
            fi
        done
    elif ! ((no_create)); then
        _rnchr_pass_env_args rnchr_stack_create "$stack" "${meta_args[@]}" \
            --id-var stack_id --stack-var stack_json || return

        create_services+=("${compose_services[@]}")
    fi

    # shellcheck disable=SC2034
    local co_run_result
    local co_run_commands=()

    if ((upgrade)) && ((${#recreate_services})); then
        butl.log_info "Re-creating services: ${recreate_services[*]}..."

        for service in "${recreate_services[@]}"; do
            _rnchr_pass_env_args rnchr_service_remove "$stack_id/$service" || return
        done
    fi

    if ((${#create_services[@]} + ${#recreate_services[@]} + ${#upgrade_services[@]})); then
        local secrets_json=
        _rnchr_pass_env_args rnchr_secret_list --secrets-var secrets_json || return
    fi

    if ! ((no_create)) && ((${#create_services[@]} + ${#recreate_services[@]})); then
        butl.log_info "Creating services: ${create_services[*]}..."

        for service in "${create_services[@]}" "${recreate_services[@]}"; do
            _rnchr_pass_env_args rnchr_service_create "$stack_id/$service" --silent \
                --stack-compose-json "$compose_json" "$service" --no-update-links \
                --use-secret-list "$secrets_json" || return
        done
    fi

    if ((upgrade)) && ((${#upgrade_services})); then
        butl.log_info "Upgrading services: ${upgrade_services[*]}..."

        local remote_services
        _rnchr_pass_env_args rnchr_stack_get_services "$stack_id" --services-var remote_services || return

        local upgraded_service_ids=()

        for service in "${upgrade_services[@]}"; do
            local service_json
            service_json=$(jq -Mr --arg service "$service" \
                '.[] | select(.name == $service)' <<<"$remote_services") || return

            local service_id
            service_id=$(jq -Mr --arg service "$service" '.id' <<<"$service_json") || return

            if [[ ! "$service_id" ]]; then
                butl.fail "Service $stack/$service does not exist"
                return
            fi

            _rnchr_pass_env_args rnchr_service_upgrade "$service_id" \
                --stack-compose-json "$compose_json" "$service" \
                --use-service "$service_json" --no-update-links \
                --use-secret-list "$secrets_json" || return

            upgraded_service_ids+=("$service_id")
        done
    fi

    # Update service links
    if ! ((no_update_links)) && ((${#compose_services[@]})); then
        butl.log_info "Setting service links..."

        local remote_services
        _rnchr_pass_env_args rnchr_stack_get_services "$stack_id" --services-var remote_services || return

        # Retrieve stacks and services lists
        local json_map=()
        butl.co_run json_map \
            "_rnchr_pass_env_args rnchr_stack_list" \
            "_rnchr_pass_env_args rnchr_service_list" || return

        # shellcheck disable=SC2034
        local stacks_list=${json_map[0]}
        # shellcheck disable=SC2034
        local services_list=${json_map[1]}

        local co_run_commands=()
        for service in "${compose_services[@]}"; do
            if [[ ! "$service" ]]; then
                continue
            fi

            : "_rnchr_pass_env_args rnchr_service_update_links \"\$stack_id/$service\""
            : "$_ --stack-compose-json \"\$compose_json\" \"$service\""
            local cmd="$_ --use-stack-list \"\$stacks_list\" --use-service-list \"\$services_list\""

            co_run_commands+=("$cmd")
        done

        butl.co_run "" "${co_run_commands[@]}" || return
    fi

    if ! ((no_finish_upgrade)) && { ((upgrade)) || ! ((no_create)); }; then
        butl.log_info "Finishing upgrade..."

        local args=("$stack_id")
        if ((await)); then
            args+=(--wait)
        fi

        _rnchr_pass_env_args rnchr_stack_finish_upgrade "${args[@]}"
    fi

    # Ensure that secrets are mounted
    butl.log_info "Ensuring secrets are mounted when applicable..."
    _rnchr_pass_env_args rnchr_stack_ensure_secrets_mounted "$stack" \
        --finish-upgrade-timeout="$finish_upgrade_timeout"
}

rnchr_stack_util_build_dependency_arrays() {
    local stack_compose=$1
    local arrays_var=$2
    shift

    local services
    if (($#)); then
        services=("$@")
    else
        local service_lines=
        service_lines=$(jq -Mr '.services | keys[]' <<<"$stack_compose")

        butl.split_lines services "$service_lines"
    fi

    printf -- '%s\n' "${services[@]}"
}
