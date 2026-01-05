#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"

# Load shared test helpers
# shellcheck source=test_helpers.bash
source "${BATS_TEST_DIRNAME}/test_helpers.bash"

# Uncomment the following line to debug stub failures
# export CURL_STUB_DEBUG=/dev/tty
# export DOCKER_STUB_DEBUG=/dev/tty

setup() {
  export TMPDIR="$(mktemp -d)"
  export BUILDKITE_JOB_ID="test-job-123"
  export BUILDKITE_AGENT_ACCESS_TOKEN="test-token"
  export TEST_USE_STUBS="true"

  # Set up stub bin directory for chinmina_token stubs
  setup_stub_bin
  add_openssl_stub

  # Create cache so OIDC requests aren't made in stub tests
  CACHE_FILE="${TMPDIR}/chinmina-oidc-${BUILDKITE_JOB_ID}.cache"
  echo "cached-oidc-token" | base64 > "$CACHE_FILE"
}

teardown() {
  rm -rf "${TMPDIR}"
  unset BUILDKITE_JOB_ID
  unset BUILDKITE_AGENT_ACCESS_TOKEN
  unset TMPDIR
  unset TEST_USE_STUBS
}

run_environment() {
  echo "Running environment hook with args: $*"
  run bash -c 'source "$*" && env' _ "$*"
}

@test "fails when Chinmina url parameter is not set via plugin or agent environment" {
  run "$PWD/hooks/environment"

  assert_failure
  assert_output --partial "chinmina-url is required (via plugin parameter or agent environment)"
}

@test "adds function and parameters to path when configured correctly" {
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_CHINMINA_URL="test-chinmina-url"
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_AUDIENCE="test-audience"

  local expected_hooks_dir="$PWD/hooks/../bin"

  run_environment "$PWD/hooks/environment"

  assert_success

  assert_line 'CHINMINA_TOKEN_LIBRARY_FUNCTION_CHINMINA_URL=test-chinmina-url'
  assert_line 'CHINMINA_TOKEN_LIBRARY_FUNCTION_AUDIENCE=test-audience'
  assert_line --regexp ":${expected_hooks_dir}\$"
}

@test "exports single environment variable with token from profile" {
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_CHINMINA_URL="test-chinmina-url"
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_AUDIENCE="test-audience"
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_ENVIRONMENT_0="GITHUB_FOO_TOKEN=org:foo"

  stub chinmina_token "org:foo test-chinmina-url test-audience : echo 'stub-token-foo'"

  run_environment "$PWD/hooks/environment"

  assert_success
  assert_line 'GITHUB_FOO_TOKEN=stub-token-foo'

  unstub chinmina_token
}

@test "exports multiple environment variables with tokens from profiles" {
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_CHINMINA_URL="test-chinmina-url"
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_AUDIENCE="test-audience"
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_ENVIRONMENT_0="GITHUB_FOO_TOKEN=org:foo"
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_ENVIRONMENT_1="GITHUB_BAR_TOKEN=org:homebrew-tap"

  stub chinmina_token \
    "org:foo test-chinmina-url test-audience : echo 'stub-token-foo'" \
    "org:homebrew-tap test-chinmina-url test-audience : echo 'stub-token-homebrew'"

  run_environment "$PWD/hooks/environment"

  assert_success
  assert_line 'GITHUB_FOO_TOKEN=stub-token-foo'
  assert_line 'GITHUB_BAR_TOKEN=stub-token-homebrew'

  unstub chinmina_token
}

@test "succeeds when environment array is empty or missing" {
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_CHINMINA_URL="test-chinmina-url"
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_AUDIENCE="test-audience"

  run_environment "$PWD/hooks/environment"

  assert_success
}

@test "fails with invalid variable name" {
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_CHINMINA_URL="test-chinmina-url"
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_AUDIENCE="test-audience"
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_ENVIRONMENT_0="123INVALID=org:foo"

  run "$PWD/hooks/environment"

  assert_failure
  assert_output --partial "Invalid variable name: '123INVALID'"
}

@test "fails with empty profile" {
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_CHINMINA_URL="test-chinmina-url"
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_AUDIENCE="test-audience"
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_ENVIRONMENT_0="GITHUB_TOKEN="

  run "$PWD/hooks/environment"

  assert_failure
  assert_output --partial "Empty profile for: 'GITHUB_TOKEN'"
}

@test "fails when chinmina_token returns error" {
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_CHINMINA_URL="test-chinmina-url"
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_AUDIENCE="test-audience"
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_ENVIRONMENT_0="GITHUB_FOO_TOKEN=org:foo"

  stub chinmina_token "org:foo test-chinmina-url test-audience : exit 1"

  run "$PWD/hooks/environment"

  assert_failure
  assert_output --partial "Token retrieval failed for: 'org:foo'"

  unstub chinmina_token
}

# Dual-mode tests

@test "Library mode: uses agent-set defaults when plugin params not provided" {
  # Agent infrastructure sets these
  export CHINMINA_TOKEN_LIBRARY_FUNCTION_CHINMINA_URL="http://agent-url"
  export CHINMINA_TOKEN_LIBRARY_FUNCTION_AUDIENCE="agent-audience"

  run_environment "$PWD/hooks/environment"

  assert_success
  assert_line 'CHINMINA_TOKEN_LIBRARY_FUNCTION_CHINMINA_URL=http://agent-url'
  assert_line 'CHINMINA_TOKEN_LIBRARY_FUNCTION_AUDIENCE=agent-audience'
  assert_line --regexp ":$PWD/hooks/../bin\$"
}

@test "Library mode: plugin config overrides agent defaults" {
  # Agent defaults
  export CHINMINA_TOKEN_LIBRARY_FUNCTION_CHINMINA_URL="http://agent-url"
  export CHINMINA_TOKEN_LIBRARY_FUNCTION_AUDIENCE="agent-audience"

  # Plugin overrides
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_CHINMINA_URL="http://plugin-url"
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_AUDIENCE="plugin-audience"

  run_environment "$PWD/hooks/environment"

  assert_success
  assert_line 'CHINMINA_TOKEN_LIBRARY_FUNCTION_CHINMINA_URL=http://plugin-url'
  assert_line 'CHINMINA_TOKEN_LIBRARY_FUNCTION_AUDIENCE=plugin-audience'
  assert_line --regexp ":$PWD/hooks/../bin\$"
}

@test "Library mode: uses default audience when not provided" {
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_CHINMINA_URL="http://test-url"
  # Audience not provided - should default to "chinmina:default"

  run_environment "$PWD/hooks/environment"

  assert_success
  assert_line 'CHINMINA_TOKEN_LIBRARY_FUNCTION_CHINMINA_URL=http://test-url'
  assert_line 'CHINMINA_TOKEN_LIBRARY_FUNCTION_AUDIENCE=chinmina:default'
  assert_line --regexp ":$PWD/hooks/../bin\$"
}

@test "Environment mode: uses agent defaults and does not modify PATH" {
  # Agent infrastructure sets these
  export CHINMINA_TOKEN_LIBRARY_FUNCTION_CHINMINA_URL="http://agent-url"
  export CHINMINA_TOKEN_LIBRARY_FUNCTION_AUDIENCE="agent-audience"
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_ENVIRONMENT_0="GITHUB_TOKEN=pipeline:default"

  stub chinmina_token "pipeline:default http://agent-url agent-audience : echo 'token-from-agent-config'"

  run_environment "$PWD/hooks/environment"

  assert_success
  assert_line 'GITHUB_TOKEN=token-from-agent-config'
  # PATH should NOT contain bin/ directory in environment mode
  refute_line --regexp ":$PWD/hooks/../bin\$"

  unstub chinmina_token
}

@test "Environment mode: plugin config overrides agent defaults" {
  # Agent defaults
  export CHINMINA_TOKEN_LIBRARY_FUNCTION_CHINMINA_URL="http://agent-url"
  export CHINMINA_TOKEN_LIBRARY_FUNCTION_AUDIENCE="agent-audience"

  # Plugin overrides
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_CHINMINA_URL="http://plugin-url"
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_AUDIENCE="plugin-audience"
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_ENVIRONMENT_0="GITHUB_TOKEN=pipeline:default"

  stub chinmina_token "pipeline:default http://plugin-url plugin-audience : echo 'token-from-plugin-config'"

  run_environment "$PWD/hooks/environment"

  assert_success
  assert_line 'GITHUB_TOKEN=token-from-plugin-config'
  # PATH should NOT contain bin/ directory in environment mode
  refute_line --regexp ":$PWD/hooks/../bin\$"

  unstub chinmina_token
}

@test "Environment mode: uses default audience when not provided" {
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_CHINMINA_URL="http://test-url"
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_ENVIRONMENT_0="GITHUB_TOKEN=pipeline:default"

  stub chinmina_token "pipeline:default http://test-url chinmina:default : echo 'token-with-default-audience'"

  run_environment "$PWD/hooks/environment"

  assert_success
  assert_line 'GITHUB_TOKEN=token-with-default-audience'

  unstub chinmina_token
}

@test "Environment mode: fails when no URL configured anywhere" {
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_ENVIRONMENT_0="GITHUB_TOKEN=pipeline:default"
  # No URL provided via plugin or agent environment

  run "$PWD/hooks/environment"

  assert_failure
  assert_output --partial "chinmina-url is required (via plugin parameter or agent environment)"
}

@test "Environment mode: calls chinmina_token with positional args" {
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_CHINMINA_URL="http://test-url"
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_AUDIENCE="test-audience"
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_ENVIRONMENT_0="MY_TOKEN=org:myorg"

  stub chinmina_token "org:myorg http://test-url test-audience : echo 'myorg-token'"

  run_environment "$PWD/hooks/environment"

  assert_success
  assert_line 'MY_TOKEN=myorg-token'

  unstub chinmina_token
}
