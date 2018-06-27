#!/usr/bin/env bash
set -eu

function usage {
  echo "Usage:

  $(basename "$0") <planet4-release-name>

Example:

  $(basename "$0") planet4-flibble-release

The following environment variables are tested for Client ID and Secret:

  GA_CLIENT_ID
  GA_CLIENT_SECRET

These are expected to be base64 encoded.

If these variables are not set and the terminal is interactive, you can enter
them at the prompt. If the terminal is not interactive, an error will be shown.

"
}

if [[ -z "${1:-}" ]]
then
  >&2 echo "Error: Release name not set"
  >&2 echo
  usage
  exit 1
fi

release=$1

# Check if interactive
if ! tty -s
then
  # Non-interactive shell, exit with error if variables are unset
  [[ -z "$GA_CLIENT_ID" ]] && >&2 echo "Error: GA_CLIENT_ID not set." && exit 1
  [[ -z "$GA_CLIENT_SECRET" ]] && >&2 echo "Error: GA_CLIENT_SECRET not set." && exit 1
fi

if [[ -z "$GA_CLIENT_ID" ]]
then
  read -s -p "Google Apps Login client ID: " GA_CLIENT_ID
  echo
else
  # Read base64 encoded var from environment
  GA_CLIENT_ID=$(base64 -d <<< $GA_CLIENT_ID)
fi

if [[ -z "$GA_CLIENT_SECRET" ]]
then
  read -s -p "Google Apps Login client secret: " GA_CLIENT_SECRET
  echo
else
  # Read base64 encoded var from environment
  GA_CLIENT_SECRET=$(base64 -d <<< $GA_CLIENT_SECRET)
fi

./update_release_wp_array_option.sh $release galogin ga_clientid $GA_CLIENT_ID
./update_release_wp_array_option.sh $release galogin ga_clientsecret $GA_CLIENT_SECRET

./flush_release_redis.sh $release
