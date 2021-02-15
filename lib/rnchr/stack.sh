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
        query="id=$name"
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

    local id_field=
    if [[ "$name" =~ ^1st[[:digit:]]+ ]]; then
        id_field="id"
    else
        id_field="name"
    fi

    local response=
    _rnchr_pass_env_args rnchr_env_api \
        --response-var response \
        "stacks" --get --data-urlencode "$id_field=$name" || return

    [[ "$response" && "$(jq -Mr --arg field "$id_field" '.data[0][$field] | select(. != null)' <<<"$response")" ]]
}

rnchr_stack_wait_for_containers_to_stop() {
    local stack_name=$1

    if [[ "$stack_name" =~ 1st[[:digit:]]+ ]]; then
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
