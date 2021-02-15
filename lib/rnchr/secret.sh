#!/usr/bin/env bash

bgen:import butl/muffle

bgen:import _utils.sh
bgen:import api.sh

rnchr_secret_list() {
    _rnchr_env_args
    barg.arg secrets_var \
        --long=secrets-var \
        --value=variable \
        --desc="Set the shell variable instead"

    local rancher_url=
    local rancher_access_key=
    local rancher_secret_key=
    local rancher_env=
    local secrets_var=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local response=
    _rnchr_pass_env_args rnchr_env_api \
        --response-var response \
        "secrets" --get --data-urlencode "$query" || return

    local _output=
    _output=$(jq -Mc '.data' <<<"$response") || return

    if [[ "$secrets_var" ]]; then
        butl.set_var "$secret_var" "$_output"
    else
        echo "$_output"
    fi
}

rnchr_secret_get() {
    _rnchr_env_args
    barg.arg name \
        --required \
        --value=SECRET \
        --desc="Secret to inspect"
    barg.arg secret_var \
        --long=secret-var \
        --value=variable \
        --desc="Set the shell variable instead"

    local rancher_url=
    local rancher_access_key=
    local rancher_secret_key=
    local rancher_env=
    local name=
    local secret_var=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local query=
    if [[ "$name" =~ 1se[[:digit:]]+ ]]; then
        query="id=$name"
    else
        query="name=$name"
    fi

    local response=
    _rnchr_pass_env_args rnchr_env_api \
        --response-var response \
        "secrets" --get --data-urlencode "$query" || return

    if [[ "$response" && "$(jq -Mr '.data | length' <<<"$response")" -gt 0 ]]; then
        local json
        json=$(jq -Mc '.data[0] | select(. != null)' <<<"$response") || return

        if [[ "$json" ]]; then
            if [[ "$secret_var" ]]; then
                butl.set_var "$secret_var" "$json"
            else
                echo "$json"
            fi

            return
        fi
    fi

    butl.fail "Secret ${BUTL_ANSI_UNDERLINE}$name${BUTL_ANSI_RESET_UNDERLINE} not found"
}

rnchr_secret_get_id() {
    _rnchr_env_args
    barg.arg name \
        --required \
        --value=SECRET \
        --desc="Secret to inspect"
    barg.arg id_var \
        --long=id-var \
        --value=variable \
        --desc="Set the shell variable instead"

    local rancher_url=
    local rancher_access_key=
    local rancher_secret_key=
    local rancher_env=
    local name=
    local id_var=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local secret_id=
    if [[ "$name" =~ 1se[[:digit:]]+ ]]; then
        secret_id=$name
    else
        local secret=
        _rnchr_pass_env_args rnchr_secret_get \
            --secret-var secret \
            "$name" || return

        secret_id=$(jq -Mr '.id' <<<"$secret")
    fi

    if [[ "$id_var" ]]; then
        butl.set_var "$id_var" "$secret_id"
    else
        echo "$secret_id"
    fi

    return
}

rnchr_secret_create() {
    _rnchr_env_args
    barg.arg name \
        --required \
        --value=NAME \
        --desc="Name of the secret"
    barg.arg file \
        --required \
        --value=FILE \
        --desc="File containing the value of the secret (use - to read from stdin)"
    barg.arg desc \
        --short=d \
        --long=desc \
        --value=DESCRIPTION \
        --desc="Description of the secret"
    barg.arg desc_hash \
        --short=h \
        --long=desc-hash \
        --desc="Append the value's hash to the description"

    local rancher_url=
    local rancher_access_key=
    local rancher_secret_key=
    local rancher_env=
    local name=
    local file=
    local desc=
    local desc_hash=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    local value=
    if [[ "$file" == "-" ]]; then
        # Read value from stdin if equals -
        value=$(base64)
    elif ! [[ -r "$file" && -f "$file" ]]; then
        value=$(base64 <"$file")
    fi

    # Add the hash to the description
    if ((desc_hash)); then
        local hash
        hash=$(printf '%s' "$value" | sha256sum)

        if [[ "$desc" ]]; then
            desc+=$'\n'
        fi

        desc+="sha256:${hash%%[[:space:]]*}"
    fi

    # Create the payload
    local payload=
    payload=$(jq -Mcn \
        --arg name "$name" \
        --arg value "$value" \
        --arg desc "$desc" \
        '{
            "name": $name,
            "value": $value,
            "description": $desc
        }') || return

    butl.muffle_all _rnchr_pass_env_args rnchr_env_api \
        "secrets" -X POST -d "$payload"
}

rnchr_secret_delete() {
    _rnchr_env_args
    barg.arg name \
        --required \
        --value=NAME \
        --desc="Name of the secret"

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

    local secret_id=
    rnchr_secret_get_id "$name" --id-var secret_id || return

    butl.muffle_all _rnchr_pass_env_args rnchr_env_api \
        "secrets/$secret_id" -X DELETE
}

rnchr_secret_sync() {
    _rnchr_env_args
    barg.arg file \
        --required \
        --value=FILE \
        --desc="DotEnv file to sync secrets from"

    local rancher_url=
    local rancher_access_key=
    local rancher_secret_key=
    local rancher_env=
    local file=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    if ! [[ -f "$file" && -r "$file" ]]; then
        : "File ${BUTL_ANSI_UNDERLINE}$file${BUTL_ANSI_RESET_UNDERLINE}"
        butl.fail "$_ does not exist or is not readable"
    fi

    (
        # shellcheck disable=SC1090
        source "$file"

        local line=
        while read -r line; do
            : "${line%%=*}"
            : "${_##*[[:space:]]}"
            local env_var=$_

            if ! declare -p "$env_var" 1>/dev/null 2>/dev/null; then
                continue
            fi

            local value=${!env_var}

            local hash=
            __rnchr_secret_get_hash "$value" hash >/dev/null

            local secret_desc=
            local remote_hash=
            __rnchr_secret_get_remote_hash \
                secret_desc \
                remote_hash \
                --url="$rancher_url" \
                --access-key="$rancher_access_key" \
                --secret-key="$rancher_secret_key" \
                --env="$rancher_env" \
                "$env_var" >/dev/null 2>/dev/null || true

            if [[ "$remote_hash" != "$hash" ]]; then
                butl.log_debug "Removing $env_var"
                local secret_id=
                if _rnchr_pass_env_args rnchr_secret_exists "$env_var"; then
                    _rnchr_pass_env_args rnchr_secret_delete "$env_var" || return
                fi

                local desc=
                if [[ "$remote_hash" ]]; then
                    desc=${secret_desc//$remote_hash/$hash}
                else
                    if [[ "$secret_desc" =~ [^[:space]] ]]; then
                        desc+=$'\n'
                    fi
                    desc+="sha256:$hash"
                fi

                butl.log_debug "Creating $env_var with desc: $desc"
                printf '%s' "$value" | rnchr_secret_create \
                    --url="$rancher_url" \
                    --access-key="$rancher_access_key" \
                    --secret-key="$rancher_secret_key" \
                    --env="$rancher_env" \
                    "$env_var" - --desc="$desc" || return
            fi
        done <"$file"
    ) || return
}

# Returns the sha256 hash for a given string
__rnchr_secret_get_hash() {
    local _str=$1
    local _variable=${2:-}

    local _output
    _output=$(printf '%s' "$_str" | sha256sum)

    local _hash=${_output%%[[:space:]]*}

    if [[ "$_variable" ]]; then
        butl.set_var "$_variable" "$_hash"
    else
        echo "$_hash"
    fi
}

# Gets the hash from Rancher's secret description
__rnchr_secret_get_remote_hash() {
    local _secret_desc_var=$1
    local _remote_hash_var=$2
    shift 2

    local _secret=
    rnchr_secret_get --secret-var _secret "$@" || return

    local _desc=
    _desc=$(jq -Mr '.description' <<<"$_secret") || return

    if [[ "$_desc" =~ .*sha256:([[:xdigit:]]+) ]]; then
        local _hash=${BASH_REMATCH[1]}
        butl.set_var "$_remote_hash_var" "$_hash"
        butl.set_var "$_secret_desc_var" "$_desc"
        return 0
    fi

    return 1
}

rnchr_secret_exists() {
    _rnchr_env_args
    barg.arg name \
        --required \
        --value=SECRET \
        --desc="Secret to inspect"

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

    local id_field=
    if [[ "$name" =~ 1se[[:digit:]]+ ]]; then
        id_field="id"
    else
        id_field="name"
    fi

    local response=
    _rnchr_pass_env_args rnchr_env_api \
        --response_var response \
        "secrets" --get --data-urlencode "$id_field=$name" >/dev/null || return

    [[ "$response" && "$(jq -Mr --arg field "$id_field" '.data[0][$field] | select(. != null)' <<<"$response")" ]]
}
