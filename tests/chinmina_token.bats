#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"

# Uncomment the following line to debug stub failures
# export CURL_STUB_DEBUG=/dev/tty
# export DOCKER_STUB_DEBUG=/dev/tty

setup() {
  # Setting up a default (test) job id for Buildkite
  export BUILDKITE_JOB_ID="7216989073"
  OIDC_TOKEN="example-token"

  #Path to the cache file
  CACHE_FILE="/tmp/oidc_auth_token_${BUILDKITE_JOB_ID}.cache"
  echo "$OIDC_TOKEN" > "$CACHE_FILE"
  export CACHE_FILE

  # values configured by environment hook
  export CHINMINA_TOKEN_LIBRARY_FUNCTION_CHINMINA_URL="http://sample-chinmina-url"
  export CHINMINA_TOKEN_LIBRARY_FUNCTION_AUDIENCE="default"
}

teardown() {
  unstub curl
  rm -rf $CACHE_FILE

  unset BUILDKITE_JOB_ID
  unset CHINMINA_TOKEN_LIBRARY_FUNCTION_CHINMINA_URL
  unset CHINMINA_TOKEN_LIBRARY_FUNCTION_AUDIENCE
}

@test "fetches the chinmina token for default profile when no argument is provided" {
  stub curl "echo '{\"profile\": \"default\", \"organisationSlug\": \"org123\", \"token\": \"default-token\", \"expiry\": $(date +%s)}'"

  run './bin/chinmina_token'

  assert_success
  assert_output --partial "default-token"
}

@test "fetches the chinmina token for default profile by using the cached oidc token" {
  local profile="default"

  stub curl "echo '{\"profile\": \"default\", \"organisationSlug\": \"org123\", \"token\": \"728282727\", \"expiry\": $(date +%s)}'"

  run './bin/chinmina_token' $profile

  assert_success
  assert_output --partial "728282727"
}

@test "fetches the chinmina token for an org profile without a cached oidc token" {
  # remove cache created in setup
  rm -rf $CACHE_FILE

  local oidc_token="sample-token"
  local profile="org:sample-profile"

  stub buildkite-agent \
    "oidc request-token --claim pipeline_id --audience "default" : echo '${oidc_token}'"

  stub curl "echo '{\"profile\": \"profile-name\", \"organisationSlug\": \"org123\", \"token\": \"728282727\", \"expiry\": $(date +%s)}'"

  run './bin/chinmina_token' $profile

  assert_success
  assert_output --partial "728282727"

  unstub buildkite-agent
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

  stub curl "echo '{\"profile\": \"${profile}\", \"organisationSlug\": \"org123\", \"token\": \"\", \"expiry\": $(date +%s)}'"

  run './bin/chinmina_token' $profile

  assert_failure
  assert_output --partial "request failed: empty token returned in Chinmina response"
}

@test "Adds url and audience config" {
  export CHINMINA_TOKEN_LIBRARY_FUNCTION_CHINMINA_URL=http://test-location
  export CHINMINA_TOKEN_LIBRARY_FUNCTION_AUDIENCE=default

  local profile="default"

  stub curl "echo '{\"profile\": \"${profile}\", \"organisationSlug\": \"org123\", \"token\": \"728282727\", \"expiry\": $(date +%s)}'"

  run './bin/chinmina_token' $profile

  assert_success
  assert_output --partial "728282727"
}
