#!/usr/bin/env bash

rnchr_service_get() {
    rnchr_env_args
    barg.arg name \
        --required \
        --value=container \
        --desc="Container to get the ID of"

    local rancher_url=
    local rancher_access_key=
    local rancher_secret_key=
    local rancher_env=
    local name=
    barg.parse "$@"

    # If the name contains a slash, assume it's <stack>/<service>
    if [[ "$name" =~ \/ ]]; then
        local stack_name=${name%%\/*}
        local service_name=${name##*\/}

        local json=
        json=$(rnchr_env_api \
            --url "$rancher_url" \
            --access-key "$rancher_access_key" \
            --secret-key "$rancher_secret_key" \
            --env "$rancher_env" \
            "stacks" \
            --get --data-urlencode "name=$stack_name") || return

        if [[ "$json" && "$(jq -Mr '.data | length' <<<"$json")" -ne 0 ]]; then
            local stack_id
            stack_id=$(jq -Mr '.data[0].id' <<<"$json")

            json=$(rnchr_env_api \
                --url "$rancher_url" \
                --access-key "$rancher_access_key" \
                --secret-key "$rancher_secret_key" \
                --env "$rancher_env" \
                "stacks/$stack_id/services") || return

            if [[ "$json" && "$(jq -Mr '.data | length' <<<"$json")" -ne 0 ]]; then
                json=$(jq -Mc --arg service "$service_name" '
                    .data[] | select(.name == $service) | .
                ' <<<"$json")

                if [[ "$json" ]]; then
                    echo "$json"
                    return
                fi
            fi
        fi
    fi

    if [[ "$name" =~ 1s[[:digit:]]+ ]]; then
        local json=
        json=$(rnchr_env_api \
            --url "$rancher_url" \
            --access-key "$rancher_access_key" \
            --secret-key "$rancher_secret_key" \
            --env "$rancher_env" \
            "services" \
            --get --data-urlencode "name=$name") || return

        if [[ "$json" && "$(jq -Mr '.data | length' <<<"$json")" -ne 0 ]]; then
            json=$(jq -Mc --arg service "$service_name" '
                .data[] | select(.name == $service) | .
            ' <<<"$json")

            if [[ "$json" ]]; then
                echo "$json"
                return
            fi
        fi
    fi

    butl.fail "Service ${BUTL_ANSI_UNDERLINE}$name${BUTL_ANSI_RESET_UNDERLINE} not found"
}
