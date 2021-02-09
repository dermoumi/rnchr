#!/usr/bin/env bash

bgen:import butl/muffle

bgen:import _utils.sh
bgen:import api.sh

rnchr_secret_get() {
    rnchr_env_args
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

    local query=
    if [[ "$name" =~ 1se[[:digit:]]+ ]]; then
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
        "secrets" --get --data-urlencode "$query" >/dev/null || return

    if [[ "$r_resp" && "$(jq -Mr '.data | length' <<<"$r_resp")" -gt 0 ]]; then
        local json
        json=$(jq -Mc '.data[0] | select(. != null)' <<<"$r_resp") || return

        if [[ "$json" ]]; then
            if butl.is_declared r_secret; then
                # shellcheck disable=SC2034
                r_secret=$json
            fi

            echo "$json"
            return
        fi
    fi

    butl.fail "Secret ${BUTL_ANSI_UNDERLINE}$name${BUTL_ANSI_RESET_UNDERLINE} not found"
}

rnchr_secret_get_id() {
    rnchr_env_args
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

    local secret_id=
    if [[ "$name" =~ 1se[[:digit:]]+ ]]; then
        secret_id=$name
    else
        local r_secret=
        rnchr_secret_get \
            --url="$rancher_url" \
            --access-key="$rancher_access_key" \
            --secret-key="$rancher_secret_key" \
            --env="$rancher_env" \
            "$name" >/dev/null || return

        secret_id=$(jq -Mr .id <<<"$r_secret")
    fi

    if butl.is_declared r_secret_id; then
        # shellcheck disable=SC2034
        r_secret_id=$secret_id
    fi

    echo "$secret_id"
    return
}

rnchr_secret_create() {
    rnchr_env_args
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

    butl.muffle_all rnchr_env_api \
        --url="$rancher_url" \
        --access-key="$rancher_access_key" \
        --secret-key="$rancher_secret_key" \
        --env="$rancher_env" \
        "secrets" -X POST -d "$payload"
}

rnchr_secret_delete() {
    rnchr_env_args
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

    local r_secret_id=
    rnchr_secret_get_id "$name" >/dev/null || return

    butl.muffle_all rnchr_env_api \
        --url="$rancher_url" \
        --access-key="$rancher_access_key" \
        --secret-key="$rancher_secret_key" \
        --env="$rancher_env" \
        "secrets/$r_secret_id" -X DELETE
}

rnchr_secret_sync() {
    rnchr_env_args
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

            local r_hash=
            __rnchr_secret_get_hash "$value" >/dev/null

            local r_secret_desc=
            local r_secret_remote_hash=
            __rnchr_secret_get_remote_hash \
                --url="$rancher_url" \
                --access-key="$rancher_access_key" \
                --secret-key="$rancher_secret_key" \
                --env="$rancher_env" \
                "$env_var" >/dev/null 2>/dev/null || true

            if [[ "$r_secret_remote_hash" != "$r_hash" ]]; then
                butl.log_debug "Removing $env_var"
                local secret_id=
                if rnchr_secret_exists \
                    --url="$rancher_url" \
                    --access-key="$rancher_access_key" \
                    --secret-key="$rancher_secret_key" \
                    --env="$rancher_env" \
                    "$env_var"; then
                    rnchr_secret_delete \
                        --url="$rancher_url" \
                        --access-key="$rancher_access_key" \
                        --secret-key="$rancher_secret_key" \
                        --env="$rancher_env" \
                        "$env_var" || return
                fi

                local desc=
                if [[ "$r_secret_remote_hash" ]]; then
                    desc=${r_secret_desc//$r_secret_remote_hash/$r_hash}
                else
                    if [[ "$r_secret_desc" =~ [^[:space]] ]]; then
                        desc+=$'\n'
                    fi
                    desc+="sha256:$r_hash"
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
    local str=$1

    local output
    output=$(printf '%s' "$str" | sha256sum)

    local hash=${output%%[[:space:]]*}

    if butl.is_declared r_hash; then
        # shellcheck disable=SC2034
        r_hash=$hash
    fi

    echo "$hash"
}

# Gets the hash from Rancher's secret description
__rnchr_secret_get_remote_hash() {
    local r_secret=
    rnchr_secret_get "$@" >/dev/null || return

    local desc=
    desc=$(jq -Mr '.description' <<<"$r_secret") || return

    if [[ "$desc" =~ .*sha256:([[:xdigit:]]+) ]]; then
        local hash=${BASH_REMATCH[1]}

        # Set the hash to the remote_hash variable if it's previously declared
        if butl.is_declared r_secret_remote_hash; then
            # shellcheck disable=SC2034
            r_secret_remote_hash=$hash
        fi

        # Set the hash to the remote_hash variable if it's previously declared
        if butl.is_declared r_secret_desc; then
            # shellcheck disable=SC2034
            r_secret_desc=$desc
        fi

        echo "$hash"
    fi
}

rnchr_secret_exists() {
    local r_secret=
    rnchr_secret_get "$@" >/dev/null 2>/dev/null || true

    [[ "$r_secret" ]]
}
