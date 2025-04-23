#!/bin/bash

# Downloads the release asset from the release URL.
# This saves to the directory where the script was called from so that the shimmed command works
# transparently. Meaning, scripts do not need to account for the location of the downloaded file and
# can handle the release asset as they normally would.
download_release() {
  local asset_url="$1"
  local release_filename="$2"
  # By default, files will download from the directory where it was called from - we want to make 
  # this concrete, so we explictly include the current working directory.
  local called_from_dir="$3"
  
  token="$(chinmina_token "org:profile-name")"

  local org_name
  org_name=$(echo "$url" | awk -F'/' '{print $4}')

  local repo_name
  repo_name=$(echo "$url" | awk -F'/' '{print $5}')

  local tag
  tag=$(echo "$url" | awk -F'/' '{print $8}')

  repo="${org_name}/${repo_name}"

  GITHUB_TOKEN="${token}" \
  gh releases download --repo "${repo}" \
    --pattern "release-file=$release_filename" \
    --dir "${TMP}/something" \
    "${tag}"


}
# Retrieves the filename from the Github Releases Browser URL.
# This is is located at the end of the URL, after the last slash.
get_release_filename() {
  local url="$1"

  #echo "retrieving release filename based on $url" >/dev/stdout

  local release_filename
  release_filename=$(echo "$url" | awk -F'/' '{print $NF}')
  
  #echo "release filename is: $release_filename" >/dev/stdout
  
  echo "$release_filename"
}