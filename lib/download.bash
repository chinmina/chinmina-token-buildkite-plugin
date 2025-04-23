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

  if [[ "$cmd" == "curl" ]]; then  
    curl \
      --silent \
      --show-error \
      --fail \
      --location \
      --header "Authorization: Bearer $GITHUB_TOKEN" \
      --header "X-GitHub-Api-Version: 2022-11-28" \
      --header "Accept: application/octet-stream" \
      --url "$asset_url" \
      --output "$called_from_dir/$release_filename"

  elif [[ "$cmd" == "wget" ]]; then
    wget \
      --quiet \
      --max-redirect=20 \
      --header "Authorization: Bearer $GITHUB_TOKEN" \
      --header "X-GitHub-Api-Version: 2022-11-28" \
      --header "Accept: application/octet-stream" \
      --quiet \
      "$asset_url" \
      --output-document="$called_from_dir/$release_filename"

  fi
}

# Retrieves the asset URL within the release manifest's assets's array based on the specified 
# release filename.
# This is the URL used to download the release asset.
get_asset_url() {
  local release_manifest="$1"
  local release_filename="$2"
  local asset_url

  asset_url=$(jq --raw-output \
  --arg filename "$release_filename" \
  '.assets[] | select(.name==$filename) | .url' \
  <<< "$release_manifest")

  echo "$asset_url"
}

# Retrieves the release manifest from the Github Releases API URL. This is in the form of a JSON
# object which contains an array of `assets` that represent the individual files for the specific
# release.
get_release_manifest() {
  local cmd="$1"
  local url="$2"

  if [ -z "${url}" ]; then
    echo -e "\e[31release url is not specified for get_release_manifest\e[0m" >/dev/stderr
    exit 1
  fi

  #echo "retrieving release manifest from $url" >/dev/stdout

  if [[ "$cmd" == "curl" ]]; then
    local release_manifest
    
    release_manifest=$(curl \
    --silent \
    --show-error \
    --fail \
    --location \
    --header "Authorization: Bearer $GITHUB_TOKEN" \
    --header "X-GitHub-Api-Version: 2022-11-28" \
    --header "Accept: application/vnd.github+json" \
    --url "$url")

  elif [[ "$cmd" == "wget" ]]; then
    local release_manifest

    release_manifest=$(wget \
    --quiet \
    --max-redirect=20 \
    --header "Authorization: Bearer $GITHUB_TOKEN" \
    --header "X-GitHub-Api-Version: 2022-11-28" \
    --header "Accept: application/vnd.github+json" \
    --quiet \
    --output-document=- \
    "$url")

  fi

  echo "$release_manifest"
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

# Using the Github Releases browser URL, construct the Github Releases API URL. This URL supports
# authenticated requests, which is necessary for acquiring releases from private repositories.
#TODO: Write a BATS test for this - we make assumptions on the URL and we need to make sure these hold across versions and different repos and the like
get_release_url() {
  local url="$1"

  #echo "retrieving release url based on $url" >/dev/stdout
  
  local org
  org=$(echo "$url" | awk -F'/' '{print $4}')

  local repo
  repo=$(echo "$url" | awk -F'/' '{print $5}')

  local tag
  tag=$(echo "$url" | awk -F'/' '{print $8}')
  
  local releases_url="https://api.github.com/repos/$org/$repo/releases/tags/$tag"

  #echo "release url is: $releases_url" >/dev/stdout

  echo "$releases_url"
}

# Check what command is being passed through to shim - if we don't support it, exit early and tell
# the user
validate_tooling() {
  local cmd="$1"

  if [[ "$cmd" != "curl" && "$cmd" != "wget" ]]; then
    echo -e "\e[31Unsupported command: $cmd\e[0m" >/dev/stderr
    exit 1
  fi
}