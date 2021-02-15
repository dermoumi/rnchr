#!/usr/bin/env bash

__rnchr_last_env_name="__@_NOT_AN_ENV_NAME__"
__rnchr_last_env_id=

rnchr_env_get_id() {
    _rnchr_args
    barg.arg environment \
        --required \
        --value=environment \
        --desc="Environment name"
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

    local environment=
    local id_var=
    barg.parse "$@"

    local env_id=
    if [[ "$environment" == "$__rnchr_last_env_name" ]]; then
        env_id=$__rnchr_last_env_id
    elif [[ ! "$environment" ]]; then
        local response=
        _rnchr_pass_args rnchr_api \
            --response-var response \
            "userpreferences?name=defaultProjectId" || return

        local env_id_json
        env_id_json=$(jq -Mr '.data[0].value | select(. != null)' <<<"$response")

        env_id=$(jq --argjson env "$env_id_json" -Mrn '$env')
    elif [[ "$environment" =~ ^1a[[:digit:]]+ ]]; then
        env_id=$environment
    else
        local response=
        _rnchr_pass_args rnchr_api \
            "projects/" \
            --response-var response \
            --get --data-urlencode "name=$environment" || return

        if [[ "$response" && "$(jq -Mr '.data | length' <<<"$response")" -ne 0 ]]; then
            env_id=$(jq -Mr '.data[0].id | select(. != null)' <<<"$response")
        fi
    fi

    if [[ ! "$env_id" ]]; then
        butl.fail "Environment $environment not found"
        return
    fi

    __rnchr_last_env_name=$environment
    __rnchr_last_env_id=$env_id
    if [[ "$id_var" ]]; then
        butl.set_var "$id_var" "$env_id"
    else
        echo "$env_id"
    fi
}
