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
  local profile="org:default"

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

  unstub buildkite-agent  # Verify OIDC request-token was called
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

  local profile="org:default"

  stub buildkite-agent "redactor add : cat > /dev/null"
  stub curl "echo '{\"profile\": \"default\", \"organisationSlug\": \"org123\", \"token\": \"728282727\", \"expiry\": $(date +%s)}'"

  run './bin/chinmina_token' $profile

  assert_success
  assert_output --partial "728282727"
}

@test "Calls buildkite-agent redactor before outputting token" {
  local profile="org:default"
  local test_token="test-secret-token-123"

  stub buildkite-agent "redactor add : cat > /dev/null"
  stub curl "echo '{\"profile\": \"default\", \"organisationSlug\": \"org123\", \"token\": \"${test_token}\", \"expiry\": $(date +%s)}'"

  run './bin/chinmina_token' $profile

  assert_success
  assert_output --partial "$test_token"

  unstub buildkite-agent  # Verify redactor was actually called
}

@test "accepts URL and audience via positional arguments" {
  local profile="org:default"
  local url="http://positional-url"
  local audience="positional-audience"

  stub buildkite-agent \
    "oidc request-token --claim \"pipeline_id,cluster_id,cluster_name,queue_id,queue_key\" --audience \"${audience}\" : echo 'positional-oidc-token'" \
    "redactor add : cat > /dev/null"

  stub curl "echo '{\"profile\": \"default\", \"organisationSlug\": \"org123\", \"token\": \"positional-token\", \"expiry\": $(date +%s)}'"

  # Clear cache to force new OIDC request
  rm -rf "${CACHE_FILE}"

  # Call with positional arguments: <profile> <url> <audience>
  run './bin/chinmina_token' "$profile" "$url" "$audience"

  assert_success
  assert_output --partial "positional-token"

  unstub buildkite-agent
}

@test "positional arguments override environment variables" {
  # Set env vars
  export CHINMINA_TOKEN_LIBRARY_FUNCTION_CHINMINA_URL="http://env-url"
  export CHINMINA_TOKEN_LIBRARY_FUNCTION_AUDIENCE="env-audience"

  local profile="org:default"
  local url="http://override-url"
  local audience="override-audience"

  stub buildkite-agent \
    "oidc request-token --claim \"pipeline_id,cluster_id,cluster_name,queue_id,queue_key\" --audience \"${audience}\" : echo 'override-oidc-token'" \
    "redactor add : cat > /dev/null"

  # Profile "org:default" routes to "organization/token/default"
  stub curl "echo '{\"profile\": \"default\", \"organisationSlug\": \"org123\", \"token\": \"override-token\", \"expiry\": $(date +%s)}'"

  # Clear cache to force new OIDC request
  rm -rf "${CACHE_FILE}"

  # Positional args should override env vars
  run './bin/chinmina_token' "$profile" "$url" "$audience"

  assert_success
  assert_output --partial "override-token"

  unstub buildkite-agent
}

@test "fails when URL not provided via argument or environment" {
  # Clear env vars
  unset CHINMINA_TOKEN_LIBRARY_FUNCTION_CHINMINA_URL
  unset CHINMINA_TOKEN_LIBRARY_FUNCTION_AUDIENCE

  local profile="org:default"

  # No stubs needed as it should fail before making any calls

  run './bin/chinmina_token' "$profile"

  assert_failure
  assert_output --partial "Error: chinmina-url not provided in environment or as an argument"
}

@test "uses default audience when not provided" {
  # Unset env vars from setup() so we test the built-in default
  unset CHINMINA_TOKEN_LIBRARY_FUNCTION_CHINMINA_URL
  unset CHINMINA_TOKEN_LIBRARY_FUNCTION_AUDIENCE

  local profile="org:default"
  local url="http://test-url"
  # audience intentionally not provided - should default to "chinmina:default"

  stub buildkite-agent \
    "oidc request-token --claim \"pipeline_id,cluster_id,cluster_name,queue_id,queue_key\" --audience \"chinmina:default\" : echo 'default-audience-oidc-token'" \
    "redactor add : cat > /dev/null"

  stub curl "echo '{\"profile\": \"default\", \"organisationSlug\": \"org123\", \"token\": \"default-audience-token\", \"expiry\": $(date +%s)}'"

  # Clear cache to force new OIDC request
  rm -rf "${CACHE_FILE}"

  # Call with only profile and url - audience should default
  run './bin/chinmina_token' "$profile" "$url"

  assert_success
  assert_output --partial "default-audience-token"

  unstub buildkite-agent
}

@test "fetches token using pipeline: prefix and routes to /token endpoint" {
  stub buildkite-agent "redactor add : cat > /dev/null"
  stub curl "echo '{\"profile\": \"default\", \"organisationSlug\": \"org123\", \"token\": \"pipeline-token\", \"expiry\": $(date +%s)}'"

  run './bin/chinmina_token' "pipeline:default"

  assert_success
  assert_output --partial "pipeline-token"
}

@test "repo: prefix still works but emits deprecation warning" {
  stub buildkite-agent "redactor add : cat > /dev/null"
  stub curl "echo '{\"profile\": \"default\", \"organisationSlug\": \"org123\", \"token\": \"repo-token\", \"expiry\": $(date +%s)}'"

  run './bin/chinmina_token' "repo:default"

  assert_success
  assert_output --partial "repo-token"
  assert_output --partial "Warning: 'repo:' prefix is deprecated"
}

@test "default profile is pipeline:default" {
  stub buildkite-agent "redactor add : cat > /dev/null"
  # The curl stub doesn't need to verify the path since we're testing default behavior
  stub curl "echo '{\"profile\": \"default\", \"organisationSlug\": \"org123\", \"token\": \"default-token\", \"expiry\": $(date +%s)}'"

  run './bin/chinmina_token'

  assert_success
  # Should NOT emit deprecation warning (since default is now pipeline:default)
  refute_output --partial "deprecated"
}

@test "fails when profile has no colon separator" {
  run './bin/chinmina_token' "invalid-profile"

  assert_failure
  assert_output --partial "Error: invalid profile format 'invalid-profile'"
  assert_output --partial "Must be 'prefix:name'"
}

@test "fails when profile name contains invalid characters" {
  run './bin/chinmina_token' "pipeline:bad/name"

  assert_failure
  assert_output --partial "Error: invalid profile name 'bad/name'"
  assert_output --partial "Must contain only alphanumeric"
}

@test "fails when profile has unrecognized prefix" {
  run './bin/chinmina_token' "unknown:profile"

  assert_failure
  assert_output --partial "Error: unrecognized profile prefix 'unknown'"
  assert_output --partial "Use 'pipeline:' or 'org:'"
}

@test "works when TMPDIR is not set and defaults to /tmp" {
  # Unset TMPDIR to test default behavior
  unset TMPDIR

  # Remove any existing cache file from setup
  rm -rf "/tmp/chinmina-oidc-${BUILDKITE_JOB_ID}.cache"

  local oidc_token="default-fallback-token"
  local profile="pipeline:default"

  stub buildkite-agent \
    "oidc request-token --claim \"pipeline_id,cluster_id,cluster_name,queue_id,queue_key\" --audience \"default\" : echo '${oidc_token}'" \
    "redactor add : cat > /dev/null"

  stub curl "echo '{\"profile\": \"default\", \"organisationSlug\": \"org123\", \"token\": \"fallback-success-token\", \"expiry\": $(date +%s)}'"

  run './bin/chinmina_token' "$profile"

  assert_success
  assert_output --partial "fallback-success-token"

  # Verify cache file was created in /tmp
  [[ -f "/tmp/chinmina-oidc-${BUILDKITE_JOB_ID}.cache" ]]

  # Clean up
  rm -f "/tmp/chinmina-oidc-${BUILDKITE_JOB_ID}.cache"

  unstub buildkite-agent
}
