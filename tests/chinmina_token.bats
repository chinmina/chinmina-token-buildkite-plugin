#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"

# Uncomment the following line to debug stub failures
# export CURL_STUB_DEBUG=/dev/tty
# export DOCKER_STUB_DEBUG=/dev/tty

setup(){

    # Setting up a default (test) job id for Buildkite
    export BUILDKITE_JOB_ID="7216989073"
    OIDC_TOKEN="example-token"

    #Path to the cache file
    CACHE_FILE="/tmp/oidc_auth_token_${BUILDKITE_JOB_ID}.cache"
    echo "$OIDC_TOKEN" > "$CACHE_FILE"
    export CACHE_FILE

}

teardown(){
    unstub curl 
    rm -rf $CACHE_FILE
    
    unset BUILDKITE_JOB_ID
    unset BUILDKITE_PLUGIN_CHINMINA_TOKEN_LIBRARY_CHINMINA_URL
    unset BUILDKITE_PLUGIN_CHINMINA_TOKEN_LIBRARY_AUDIENCE
}

@test "fetches the chinmina token for default profile by using the cached oidc token" {

    local profile="default"

    stub curl "echo '{\"profile\": \"default\", \"organisationSlug\": \"org123\", \"token\": \"728282727\", \"expiry\": $(date +%s)}'"

    run './bin/chinmina_token' $profile

    assert_success
    assert_output --partial "728282727"

}

@test "try to fetch the chinmina token for an invalid profile" {

    local profile="org:invalid-profile"

    stub curl "echo '{\"error\": \"invalid profile\"}'"

    run './bin/chinmina_token' $profile

    assert_failure
    assert_output --partial "request failed: no token returned in Chinmina response"
}

@test "try to fetch the chinmina token for a profile without permissions" {

    local profile="org:unauthorized-profile"

    stub curl "echo '{\"profile\": \"default\", \"organisationSlug\": \"org123\", \"token\": \"\", \"expiry\": $(date +%s)}'"

    run './bin/chinmina_token' $profile

    assert_failure
    assert_output --partial "request failed: token doesn't exist in Chinmina response"
}

@test "Adds url and audience config" {
    export BUILDKITE_PLUGIN_CHINMINA_TOKEN_LIBRARY_CHINMINA_URL=http://test-location
    export BUILDKITE_PLUGIN_CHINMINA_TOKEN_LIBRARY_AUDIENCE=default
  
    local profile="default"

    stub curl "echo '{\"profile\": \"default\", \"organisationSlug\": \"org123\", \"token\": \"728282727\", \"expiry\": $(date +%s)}'"

    run './bin/chinmina_token' $profile

    assert_success
    assert_output --partial "728282727"
}


