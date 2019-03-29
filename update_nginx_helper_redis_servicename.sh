#!/usr/bin/env bash
set -eu

function usage {
  echo "Usage:

  $(basename "$0") <helm-release-name> [<namespace>] [<redis_servicename>]

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

namespace=${2:-$(./get_namespace.sh "$release")}

redis_servicename=$(kubectl -n "$namespace" get service -l "app=redis,release=$release" -o name | cut -d/ -f2)

./update_release_wp_array_option.sh "$release" "$namespace" rt_wp_nginx_helper_options redis_hostname "$redis_servicename"
