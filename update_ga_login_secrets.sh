#!/usr/bin/env bash
set -eo pipefail

function usage {
  echo "Usage:

  $(basename "$0") [<planet4-release-name>] [<helm-namespace>]

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

release=${1:-${HELM_RELEASE}}

#
# Determine namespace from release
#
namespace=${2:-${HELM_NAMESPACE:-$(./get_namespace.sh $release)}}
if ! kubectl get namespace $namespace > /dev/null
then
  echo "ERROR: Namespace '$namespace' not found."
  exit 1
fi
echo "Namespace:  $namespace"

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
  GA_CLIENT_ID=$(echo $GA_CLIENT_ID | openssl base64 -a -A -d | tr -d '\n')
fi

if [[ -z "$GA_CLIENT_SECRET" ]]
then
  read -s -p "Google Apps Login client secret: " GA_CLIENT_SECRET
  echo
else
  # Read base64 encoded var from environment
  GA_CLIENT_SECRET=$(echo $GA_CLIENT_SECRET | openssl base64 -a -A -d | tr -d '\n')
fi

./update_release_wp_array_option.sh $release $namespace galogin ga_clientid $GA_CLIENT_ID
./update_release_wp_array_option.sh $release $namespace galogin ga_clientsecret $GA_CLIENT_SECRET
