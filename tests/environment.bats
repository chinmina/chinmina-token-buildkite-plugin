#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"

# Uncomment the following line to debug stub failures
# export CURL_STUB_DEBUG=/dev/tty
# export DOCKER_STUB_DEBUG=/dev/tty

run_environment() {
  echo "Running environment hook with args: $*"
  run bash -c 'source "$*" && env' _ "$*"
}

@test "fails when Chinmina url parameter is not set" {
  run "$PWD/hooks/environment"

  assert_failure
  assert_output --partial "BUILDKITE_PLUGIN_CHINMINA_TOKEN_CHINMINA_URL: chinmina-url parameter is required"
}

@test "fails when the audience parameter is not set" {
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_CHINMINA_URL="configured"

  run "$PWD/hooks/environment"

  assert_failure
  assert_output --partial "BUILDKITE_PLUGIN_CHINMINA_TOKEN_AUDIENCE: audience parameter is required"
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

@test "exports single environment variable with profile as interim value" {
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_CHINMINA_URL="test-chinmina-url"
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_AUDIENCE="test-audience"
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_ENVIRONMENT_0="GITHUB_TOKEN_FOO=org:foo"

  run_environment "$PWD/hooks/environment"

  assert_success
  assert_line 'GITHUB_TOKEN_FOO=org:foo'
}

@test "exports multiple environment variables with profiles as interim values" {
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_CHINMINA_URL="test-chinmina-url"
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_AUDIENCE="test-audience"
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_ENVIRONMENT_0="GITHUB_TOKEN_FOO=org:foo"
  export BUILDKITE_PLUGIN_CHINMINA_TOKEN_ENVIRONMENT_1="GITHUB_TOKEN_BAR=org:homebrew-tap"

  run_environment "$PWD/hooks/environment"

  assert_success
  assert_line 'GITHUB_TOKEN_FOO=org:foo'
  assert_line 'GITHUB_TOKEN_BAR=org:homebrew-tap'
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
