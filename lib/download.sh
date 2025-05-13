#!/bin/bash

main() {
  local repo="$1"
  local tag="$2"
  local release_filename="$3"
  local output="$4"

  GITHUB_TOKEN="${token}" \
  gh releases download --repo "${repo}" \
    --pattern "release-file=$release_filename" \
    --dir "${output}" \
    "${tag}"

}

main "$@"