#!/usr/bin/env bash
set -eu

function usage {
  echo "Usage:

  $(basename "$0") <planet4-release-name> [<redis_servicename>]

Example:

  $(basename "$0") planet4-flibble-release

If <redis_servicename> is not set, the Helm binary is required to detect the
redis servicename. See https://helm.sh

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
namespace=$2

redis_servicename=$(helm status $release | grep Service -A 10 | grep redis | head -n1 | cut -d' ' -f1)

./update_release_wp_array_option.sh $release $namespace rt_wp_nginx_helper_options redis_hostname $redis_servicename
