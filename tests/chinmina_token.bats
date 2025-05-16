#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"

# Uncomment the following line to debug stub failures
# export CURL_STUB_DEBUG=/dev/tty
# export DOCKER_STUB_DEBUG=/dev/tty

setup(){

    # Setting up a default (test) job id for Buildkite
    export BUILDKITE_JOB_ID="7216989073"
    OIDC_TOKEN="example-token"

    # TEST_ROOT=$(mktemp -d)

    #Path to the cache file
    CACHE_FILE="/tmp/oidc_auth_token_${BUILDKITE_JOB_ID}.cache"
    echo "Name is: $CACHE_FILE"
    echo "$OIDC_TOKEN" > "$CACHE_FILE"
    export CACHE_FILE

}

teardown(){
    unstub curl 
    rm -rf $CACHE_FILE
}

@test "fetches the chinmina token for default profile by using the cached oidc token" {

    local profile="default"

    stub curl "echo '{\"profile\": \"default\", \"organisationSlug\": \"test123\", \"token\": \"728282727\", \"expiry\": $(date +%s)}'"

    run './bin/chinmina_token' "default"

    assert_success
    assert_output --partial "728282727"

}


