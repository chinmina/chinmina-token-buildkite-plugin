#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"

# Load shared test helpers
# shellcheck source=test_helpers.bash
source "${BATS_TEST_DIRNAME}/test_helpers.bash"

# Uncomment the following line to debug stub failures
# export CURL_STUB_DEBUG=/dev/tty
# export DOCKER_STUB_DEBUG=/dev/tty

setup() {
  # Setting up a default (test) job id for Buildkite
  export BUILDKITE_JOB_ID="7216989073"
  export TMPDIR="$(mktemp -d)"
  export BUILDKITE_AGENT_ACCESS_TOKEN="test-agent-token-for-encryption"
  OIDC_TOKEN="example-token"

  # Set up stub bin directory and add openssl stub for encryption
  setup_stub_bin
  add_openssl_stub

  # Path to the cache file (new location and naming)
  CACHE_FILE="${TMPDIR}/chinmina-oidc-${BUILDKITE_JOB_ID}.cache"
  # Write encrypted cache (using the stub openssl)
  echo "$OIDC_TOKEN" | base64 > "$CACHE_FILE"
  export CACHE_FILE

  # values configured by environment hook
  export CHINMINA_TOKEN_LIBRARY_FUNCTION_CHINMINA_URL="http://sample-chinmina-url"
  export CHINMINA_TOKEN_LIBRARY_FUNCTION_AUDIENCE="default"
}

teardown() {
  unstub curl
  unstub buildkite-agent || true  # may not be stubbed in all tests
  rm -rf "${TMPDIR}"

  unset BUILDKITE_JOB_ID
  unset TMPDIR
  unset BUILDKITE_AGENT_ACCESS_TOKEN
  unset CHINMINA_TOKEN_LIBRARY_FUNCTION_CHINMINA_URL
  unset CHINMINA_TOKEN_LIBRARY_FUNCTION_AUDIENCE
}

@test "fetches the chinmina token for default profile when no argument is provided" {
  stub buildkite-agent "redactor add : cat > /dev/null"
  stub curl "echo '{\"profile\": \"default\", \"organisationSlug\": \"org123\", \"token\": \"default-token\", \"expiry\": $(date +%s)}'"

  run './bin/chinmina_token'

  assert_success
  assert_output --partial "default-token"
}

@test "fetches the chinmina token for default profile by using the cached oidc token" {
  local profile="default"

  stub buildkite-agent "redactor add : cat > /dev/null"
  stub curl "echo '{\"profile\": \"default\", \"organisationSlug\": \"org123\", \"token\": \"728282727\", \"expiry\": $(date +%s)}'"

  run './bin/chinmina_token' $profile

  assert_success
  assert_output --partial "728282727"
}

@test "fetches the chinmina token for an org profile without a cached oidc token" {
  # remove cache created in setup
  rm -rf "${CACHE_FILE}"

  local oidc_token="sample-token"
  local profile="org:sample-profile"

  stub buildkite-agent \
    "oidc request-token --claim "pipeline_id,cluster_id,cluster_name,queue_id,queue_key" --audience "default" : echo '${oidc_token}'" \
    "redactor add : cat > /dev/null"

  stub curl "echo '{\"profile\": \"profile-name\", \"organisationSlug\": \"org123\", \"token\": \"728282727\", \"expiry\": $(date +%s)}'"

  run './bin/chinmina_token' $profile

  assert_success
  assert_output --partial "728282727"
}

@test "try to fetch the chinmina token for an invalid profile" {
  local profile="org:invalid-profile"

  # redactor won't be called since the request fails before we get a token
  stub curl "echo '{\"error\": \"invalid profile\"}'"

  run './bin/chinmina_token' $profile

  assert_failure
  assert_output --partial "request failed: no token returned in Chinmina response"
}

@test "try to fetch the chinmina token for a profile without permissions" {
  local profile="org:unauthorized-profile"

  # redactor won't be called since the token is empty and we fail before redacting
  stub curl "echo '{\"profile\": \"${profile}\", \"organisationSlug\": \"org123\", \"token\": \"\", \"expiry\": $(date +%s)}'"

  run './bin/chinmina_token' $profile

  assert_failure
  assert_output --partial "request failed: empty token returned in Chinmina response"
}

@test "Adds url and audience config" {
  export CHINMINA_TOKEN_LIBRARY_FUNCTION_CHINMINA_URL=http://test-location
  export CHINMINA_TOKEN_LIBRARY_FUNCTION_AUDIENCE=default

  local profile="default"

  stub buildkite-agent "redactor add : cat > /dev/null"
  stub curl "echo '{\"profile\": \"${profile}\", \"organisationSlug\": \"org123\", \"token\": \"728282727\", \"expiry\": $(date +%s)}'"

  run './bin/chinmina_token' $profile

  assert_success
  assert_output --partial "728282727"
}

@test "Calls buildkite-agent redactor before outputting token" {
  local profile="default"
  local test_token="test-secret-token-123"

  stub buildkite-agent "redactor add : cat > /dev/null"
  stub curl "echo '{\"profile\": \"${profile}\", \"organisationSlug\": \"org123\", \"token\": \"${test_token}\", \"expiry\": $(date +%s)}'"

  run './bin/chinmina_token' $profile

  assert_success
  assert_output --partial "$test_token"

  unstub buildkite-agent  # Verify redactor was actually called
}

@test "Extracts plugin version from BUILDKITE_PLUGINS for User-Agent" {
  local profile="default"
  export BUILDKITE_PLUGINS='[{"github.com/chinmina/chinmina-token-buildkite-plugin#v1.1.0":{"audience":"test","chinmina-url":"http://test"}}]'

  stub buildkite-agent "redactor add : cat > /dev/null"
  stub curl \
    "--retry 3 --retry-delay 1 --retry-connrefused --silent --show-error --fail --request POST * --data * --header * --header * --header * --header 'User-Agent: chinmina-token-buildkite-plugin/v1.1.0' : echo '{\"profile\": \"${profile}\", \"organisationSlug\": \"org123\", \"token\": \"test-token\", \"expiry\": $(date +%s)}'"

  run './bin/chinmina_token' $profile

  assert_success
  assert_output --partial "test-token"
}
