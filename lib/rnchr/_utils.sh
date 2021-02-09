#!/usr/bin/env bash

rnchr_args() {
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

rnchr_env_args() {
    rnchr_args

    barg.arg rancher_env \
        --long=env \
        --value=ENV \
        --env=RANCHER_ENVIRONMENT \
        --desc="Environment name or ID"
}
