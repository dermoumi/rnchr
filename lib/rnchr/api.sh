#!/usr/bin/env bash

bgen:import _utils.sh
bgen:import env.sh

rnchr_api() {
    rnchr_args
    barg.arg endpoint \
        --value=endpoint \
        --desc="The endpoint to call"
    barg.arg args \
        --multi \
        --value=args \
        --allow-dash \
        --desc="Arguments to pass to curl"

    local rancher_url=
    local rancher_access_key=
    local rancher_secret_key=
    local endpoint=
    local args=()
    barg.parse "$@"

    endpoint=${endpoint#/}

    local url
    if [[ "$endpoint" =~ ^https?\:\/\/ ]]; then
        url=$endpoint
    else
        rancher_url=${rancher_url%/}
        if [[ ! "$rancher_url" ]]; then
            butl.fail "${BUTL_ANSI_UNDERLINE}RANCHER_URL${BUTL_ANSI_RESET_UNDERLINE} is required"
            return
        fi

        url="${rancher_url}/${endpoint}"
    fi

    if [[ ! "$rancher_access_key" ]]; then
        butl.fail "${BUTL_ANSI_UNDERLINE}RANCHER_ACCESS_KEY${BUTL_ANSI_RESET_UNDERLINE} is required"
        return
    fi

    if [[ ! "$rancher_secret_key" ]]; then
        butl.fail "${BUTL_ANSI_UNDERLINE}RANCHER_SECRET_KEY${BUTL_ANSI_RESET_UNDERLINE} is required"
        return
    fi

    butl.log_debug "curl: $url"

    local response
    response=$(curl -sSL \
        -o - -w '\n%{http_code}\n' \
        --user "$rancher_access_key:$rancher_secret_key" \
        -H 'Accept: application/json' \
        -H 'Content-Type: application/json' \
        "${args[@]}" "${url}") || return

    local http_code=${response##*$'\n'}
    local response=${response%%$'\n'$http_code}

    if [[ "$http_code" =~ ^[23] ]]; then
        if butl.is_declared r_resp; then
            # shellcheck disable=SC2034
            r_resp=$response
        fi

        echo "$response"
        return
    fi

    rnchr_handle_err "$response"
}

rnchr_env_api() {
    rnchr_env_args
    barg.arg endpoint \
        --value=endpoint \
        --desc="The endpoint to call"
    barg.arg args \
        --multi \
        --value=args \
        --allow-dash \
        --desc="Arguments to pass to curl"

    local rancher_url=
    local rancher_access_key=
    local rancher_secret_key=
    local rancher_env=
    local endpoint=
    local args=()
    barg.parse "$@"

    # Retrieve the environment id, or default environment if unspecified
    local r_env_id=
    rnchr_env_get_id "$rancher_env" >/dev/null || return

    # Make API request
    rnchr_api "projects/${r_env_id}/${endpoint#/}" "${args[@]}"
}

rnchr_handle_err() {
    local json=$1

    local type=
    type=$(jq -Mr .type <<<"$json" 2>/dev/null) || {
        butl.fail "Unknown error: $json"
        return
    }

    if [[ "$type" == "error" ]]; then
        local status=
        status=$(jq -Mr '.status | select(. != null)' <<<"$json")
        local code=
        code=$(jq -Mr '.code | select(. != null)' <<<"$json")
        local message=
        message=$(jq -Mr '.message | select(. != null)' <<<"$json")
        local field_name=
        field_name=$(jq -Mr '.fieldName | select(. != null)' <<<"$json")

        if [[ "$code" == "NotUnique" ]]; then
            : "API error ($status): Field '${BUTL_ANSI_UNDERLINE}$field_name${BUTL_ANSI_RESET_UNDERLINE}'"
            butl.fail "$_ is not unique"
            return
        fi

        if [[ "$message" ]]; then
            butl.fail "API error ($status): $message"
            return
        fi
    fi

    butl.fail "Unknown API error: $(jq -M . <<<"$json")"
}
