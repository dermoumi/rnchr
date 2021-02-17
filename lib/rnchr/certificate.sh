#!/usr/bin/env bash

rnchr_certificate_list() {
    _rnchr_env_args
    barg.arg certificates_var \
        --long=certificates-var \
        --value=VARIABLE \
        --desc="Shell variable to store certificates list into"

    # shellcheck disable=SC2034
    local rancher_url=
    # shellcheck disable=SC2034
    local rancher_access_key=
    # shellcheck disable=SC2034
    local rancher_secret_key=
    # shellcheck disable=SC2034
    local rancher_env=

    local certificates_var=

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
        "certificates" --get \
        --data-urlencode "removed_null=1" \
        --data-urlencode "limit=-1" || return

    local __certificates_list
    __certificates_list=$(jq -Mc '.data' <<<"$_response")

    if [[ "$certificates_var" ]]; then
        butl.set_var "$certificates_var" "$__certificates_list"
    else
        echo "$__certificates_list"
    fi
}
