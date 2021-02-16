#!/usr/bin/env bash

bgen:import _utils.sh
bgen:import env.sh

rnchr_api() {
    _rnchr_args
    barg.arg __rnchr_endpoint \
        --value=endpoint \
        --desc="The endpoint to call"
    barg.arg __rnchr_args \
        --multi \
        --value=args \
        --allow-dash \
        --desc="Arguments to pass to curl"
    barg.arg __rnchr_response_var \
        --long=response-var \
        --value=variable \
        --desc="Set the shell variable instead"
    barg.arg __method \
        --long=request \
        --short=X \
        --value=METHOD \
        --default=GET \
        --desc="Method to use to send the request"
    barg.arg __payload \
        --long=data \
        --short=d \
        --value=JSON \
        --desc="Payload to send to the API"

    local rancher_url=
    local rancher_access_key=
    local rancher_secret_key=
    local __rnchr_endpoint=
    local __rnchr_args=()
    local __rnchr_response_var=
    local __method=
    local __payload=

    local should_exit=
    local should_exit_err=0
    barg.parse "$@"
    # barg.parse requested an exit
    if ((should_exit)); then
        return "$should_exit_err"
    fi

    __rnchr_endpoint=${__rnchr_endpoint#/}

    local __rnchr_url
    if [[ "$__rnchr_endpoint" =~ ^https?\:\/\/ ]]; then
        __rnchr_url=$__rnchr_endpoint
    else
        rancher_url=${rancher_url%/}
        if [[ ! "$rancher_url" ]]; then
            butl.fail "${BUTL_ANSI_UNDERLINE}RANCHER_URL${BUTL_ANSI_RESET_UNDERLINE} is required"
            return
        fi

        __rnchr_url="${rancher_url}/${__rnchr_endpoint}"
    fi

    if [[ ! "$rancher_access_key" ]]; then
        butl.fail "${BUTL_ANSI_UNDERLINE}RANCHER_ACCESS_KEY${BUTL_ANSI_RESET_UNDERLINE} is required"
        return
    fi

    if [[ ! "$rancher_secret_key" ]]; then
        butl.fail "${BUTL_ANSI_UNDERLINE}RANCHER_SECRET_KEY${BUTL_ANSI_RESET_UNDERLINE} is required"
        return
    fi

    butl.log_debug "curl: $__method $__rnchr_url"

    if [[ "$__payload" ]]; then
        __rnchr_args+=(-d "$__payload")
    fi

    local __rnchr_response
    __rnchr_response=$(curl -sSL \
        -o - -w '\n%{http_code}\n' \
        --user "$rancher_access_key:$rancher_secret_key" \
        --compressed \
        -H 'Accept: application/json' \
        -H 'Content-Type: application/json' \
        -X "$__method" \
        "${__rnchr_args[@]}" "${__rnchr_url}") || return

    local __rnchr_http_code=
    __rnchr_http_code=$(tail -n 1 <<<"$__rnchr_response")
    __rnchr_response=$(head -n -1 <<<"$__rnchr_response")

    if [[ "$__rnchr_http_code" =~ ^[23] ]]; then
        if [[ "$__rnchr_response_var" ]]; then
            butl.set_var "$__rnchr_response_var" "$__rnchr_response"
        else
            echo "$__rnchr_response"
        fi

        return
    fi

    rnchr_handle_err "$__rnchr_response" "$__payload"
}

rnchr_env_api() {
    _rnchr_env_args
    barg.arg __rnchr_endpoint \
        --value=endpoint \
        --desc="The endpoint to call"
    barg.arg __rnchr_args \
        --multi \
        --value=args \
        --allow-dash \
        --desc="Arguments to pass to curl"
    barg.arg __rnchr_response_var \
        --long=response-var \
        --value=variable \
        --desc="Set the shell variable instead"

    local rancher_url=
    local rancher_access_key=
    local rancher_secret_key=
    local rancher_env=
    local __rnchr_endpoint=
    local __rnchr_args=()
    local __rnchr_response_var=
    barg.parse "$@"

    local __rnchr_url
    if [[ "$__rnchr_endpoint" =~ ^https?\:\/\/ ]]; then
        __rnchr_url=$__rnchr_endpoint
    else
        # Retrieve the environment id, or default environment if unspecified
        local __rnchr_env_id=
        rnchr_env_get_id --id-var __rnchr_env_id "$rancher_env" || return

        __rnchr_url="projects/${__rnchr_env_id}/${__rnchr_endpoint#/}"
    fi

    # Make API request
    _rnchr_pass_args rnchr_api --response-var "$__rnchr_response_var" "$__rnchr_url" "${__rnchr_args[@]}"
}

rnchr_handle_err() {
    local json=$1
    local payload=$2

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

        local field_value=
        if [[ "$field_name" ]]; then
            local value=
            value=$(jq -Mr ".$field_name" <<<"$payload") || true

            if [[ "$value" ]]; then
                field_value=": $value"
            fi
        fi

        case "$code" in
        NotUnique)
            : "API error ($status): Field ${BUTL_ANSI_UNDERLINE}$field_name$field_value${BUTL_ANSI_RESET_UNDERLINE}"
            butl.fail "$_ is not unique"
            return
            ;;
        InvalidCharacters)
            : "API error ($status): Field ${BUTL_ANSI_UNDERLINE}$field_name$field_value${BUTL_ANSI_RESET_UNDERLINE}"
            butl.fail "$_ contains invalid characters"
            return
            ;;
        ActionNotAvailable)
            butl.fail "API error ($status): Action not available"
            return
            ;;
        MinLengthExceeded)
            : "API error ($status): Field ${BUTL_ANSI_UNDERLINE}$field_name$field_value${BUTL_ANSI_RESET_UNDERLINE}"
            butl.fail "$_ minimum length is not reached"
            return
            ;;
        MaxLengthExceeded)
            : "API error ($status): Field ${BUTL_ANSI_UNDERLINE}$field_name$field_value${BUTL_ANSI_RESET_UNDERLINE}"
            butl.fail "$_ maximum length is exceeded"
            return
            ;;
        esac

        if [[ "$message" ]]; then
            butl.fail "API error ($status): $message"
            return
        fi
    fi

    butl.fail "Unknown API error: $(jq -M . <<<"$json")"
}
