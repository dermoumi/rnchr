#!/usr/bin/env bash

_rnchr_args() {
    barg.arg rancher_url \
        --required \
        --long=url \
        --value=URL \
        --env=RANCHER_URL \
        --desc="Specify the Rancher API endpoint URL"
    barg.arg rancher_access_key \
        --required \
        --long=access-key \
        --value=ACCESS_KEY \
        --env=RANCHER_ACCESS_KEY \
        --desc="Specify the Rancher API access key"
    barg.arg rancher_secret_key \
        --required \
        --long=secret-key \
        --value=SECRET_KEY \
        --env=RANCHER_SECRET_KEY \
        --desc="Specify the Rancher API secret key"
}

_rnchr_env_args() {
    _rnchr_args

    barg.arg rancher_env \
        --long=env \
        --value=ENV \
        --env=RANCHER_ENVIRONMENT \
        --desc="Environment name or ID"
}

# shellcheck disable=SC2154
_rnchr_pass_args() {
    local __rnchr_command=$1
    shift

    "$__rnchr_command" \
        --url "$rancher_url" \
        --access-key "$rancher_access_key" \
        --secret-key "$rancher_secret_key" \
        "$@"
}

# shellcheck disable=SC2154
_rnchr_pass_env_args() {
    local __rnchr_command=$1
    shift

    _rnchr_pass_args "$__rnchr_command" --env "$rancher_env" "$@"
}

# Transforms YAML content to JSON
rnchr_util_yaml_to_json() {
    yq . -M
}

# Transforms JSON content to YAML
rnchr_util_json_to_yaml() {
    # GoTemplate has a better yaml fomatting that supports multiline strings than yq
    # but doesn't keep key order. Which doesn't really matter to us in this context
    if command -v gotemplate >/dev/null 2>&1; then
        gotemplate -c ".=stdin:///file.json" -i '{{ . | data.ToYAML }}' -o -
    else
        yq . -M -y
    fi
}
