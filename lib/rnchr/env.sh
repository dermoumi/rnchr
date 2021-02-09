#!/usr/bin/env bash

__rnchr_last_env_name="__@_NOT_AN_ENV_NAME__"
__rnchr_last_env_id=

rnchr_env_get_id() {
    rnchr_args
    barg.arg environment \
        --required \
        --value=environment \
        --desc="Environment name"

    local rancher_url=
    local rancher_access_key=
    local rancher_secret_key=
    local environment=
    barg.parse "$@"

    if [[ "$environment" == "$__rnchr_last_env_name" ]]; then
        if butl.is_declared r_env_id; then
            r_env_id=$__rnchr_last_env_id
        fi

        echo "$__rnchr_last_env_id"
        return
    fi

    if [[ ! "$environment" ]]; then
        local r_resp=
        rnchr_api \
            --url "$rancher_url" \
            --access-key "$rancher_access_key" \
            --secret-key "$rancher_secret_key" \
            "userpreferences?name=defaultProjectId" >/dev/null || return

        local default_env_id
        default_env_id=$(jq -Mr '.data[0].value | select(. | null)' <<<"$r_resp")

        local env_id=
        env_id=$(jq --argjson env "$default_env_id" -Mrn '$env')

        if [[ "$env_id" ]]; then
            __rnchr_last_env_name=$environment
            __rnchr_last_env_id=$env_id

            if butl.is_declared r_env_id; then
                r_env_id=$env_id
            fi

            echo "$env_id"
            return
        fi
    fi

    if [[ "$environment" =~ 1a[[:digit:]]+ ]]; then
        echo "$environment"
        return
    fi

    local r_resp=
    rnchr_api \
        --url "$rancher_url" \
        --access-key "$rancher_access_key" \
        --secret-key "$rancher_secret_key" \
        "projects/" \
        --get --data-urlencode "name=$environment" >/dev/null || return

    if [[ "$r_resp" && "$(jq -Mr '.data | length' <<<"$r_resp")" -ne 0 ]]; then
        local env_id=
        env_id=$(jq -Mr '.data[0].id | select(. != null)' <<<"$r_resp")

        if [[ "$env_id" ]]; then
            __rnchr_last_env_name=$environment
            __rnchr_last_env_id=$env_id

            if butl.is_declared r_env_id; then
                r_env_id=$env_id
            fi

            echo "$env_id"
            return
        fi
    fi

    butl.fail "Environment $environment not found"
}
