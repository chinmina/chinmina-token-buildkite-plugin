#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"

load '../hooks/command'

# Uncomment the following line to debug stub failures
# export [stub_command]_STUB_DEBUG=/dev/tty
#export DOCKER_STUB_DEBUG=/dev/tty

setup(){

    TEST_ROOT=$(mktemp -d)

    #Path to the shim
    SHIM_DIR="$BATS_TEST_DIRNAME/../hooks"

    CALLER_DIR="$TEST_ROOT/shim_caller"
    mkdir -p "$CALLER_DIR"

    #Test input values
    TEST_URL="https://api.github.com/repos/cultureamp/deploy-buildkite-plugin/releases/assets/728731017240"
    TEST_FILENAME="release_arm64"

    export GITHUB_TOKEN="example-token"
}

teardown(){
    unstub curl 
    rm -rf "$TEST_ROOT"
}

@test "Tests conversion of github baseURL to github api releaseURL" {
     
    input_url="https://github.com/cultureamp/deploy-buildkite-plugin/releases/download/v0.1/deploy-buildkite-plugin_darwin_arm64"
    expected_output="https://api.github.com/repos/cultureamp/deploy-buildkite-plugin/releases/tags/v1.0.0"

    run get_release_url "$input_url"

    assert_success 
    assert_output "$expected_output"

}

@test "Retrieves filename from github baseURL" {
    input_url="https://github.com/cultureamp/deploy-buildkite-plugin/releases/download/v0.1/deploy-buildkite-plugin_darwin_arm64"
    expected_output="deploy-buildkite-plugin_darwin_arm64"

    run get_release_filename "$input_url"

    assert_success 
    assert_output "$expected_output"
}

@test "fails when URL is empty" {
    run get_release_manifest curl ""
    assert_failure  
    assert_output --partial "release url is not specified"
}

@test "download_release downloads file using curl into the caller's directory" {

    stub curl \
    "echo '[stub] curl called with args: \$@' >&2; touch \$2"

    pushd "$CALLER_DIR"
    run bash -c "
        source '$SHIM_DIR/command.sh'
        cmd='curl'
        download_release '$TEST_URL' '$TEST_FILENAME' '$(pwd)'
    "
    popd
    assert_success
    assert_file_exist "$CALLER_DIR/$TEST_FILENAME"

}

# @test "download_release downloads file using wget into the caller's directory" {

#     pushd "$TEST_DIR" > /dev/null
#     run bash -c "
#         source '$SHIM_DIR/command.sh'
#         cmd='wget'
#         download_release '$TEST_URL' '$TEST_FILENAME' '$(pwd)'
#     "
#     popd > /dev/null
#     assert_success
#     assert_file_exist "$TEST_DIR/$TEST_FILENAME" 
# }