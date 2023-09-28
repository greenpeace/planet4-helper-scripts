#!/usr/bin/env bash
set -eu

function load_ga_credentials() {
  set +e
  php=$(kubectl get pods --namespace "${namespace}" \
      --field-selector=status.phase=Running \
      -l "app=planet4,component=php,release=${release}" \
      -o jsonpath="{.items[0].metadata.name}")
  option=$(kubectl -n "${namespace}" exec "$php" -- wp option get galogin --format=json)
  ga_client_id=$(jq -r '.ga_clientid' <<<"$option")
  set -e
}

#
# Ask release
#
release=${1:-}

[[ -z "$release" ]] && {

  read -rp "Enter Helm release: " release
}

#
# Ask namespace
#

namespace=${2:-}

[[ -z "$namespace" ]] && {

  read -rp "Enter Helm namespace: " namespace
}

#
# Check resource
#

if ! helm status "$release" -n "$namespace"
then
  echo "ERROR: Release '$release' not found in namespace '$namespace' ."
  exit 1
fi

#
# Determine redis pod name
#
redis=${3:-$(kubectl get pods --namespace "${namespace}" \
    --field-selector=status.phase=Running \
    -l "app.kubernetes.io/name=redis" \
    -o jsonpath="{.items[0].metadata.name}")}

if ! kubectl -n "$namespace" get pod "$redis" > /dev/null
then
  echo "ERROR: Redis pod '$redis' not found."
  exit 1
fi

#
# Encode GoogleApps ClientID
#
php=
option=

ga_client_id=${GA_CLIENT_ID:-}
if [[ -z "$ga_client_id" ]]
then
  read -rp "Use existing Google Apps login credentials from DB? [y/N] " use_existing_credentials
  echo
  case $use_existing_credentials in
      [Yy]* ) load_ga_credentials;;
      * ) : ;;
  esac

  if [ -z "$ga_client_id" ]
  then
    echo "---"
    echo
    echo "Create Google Apps OAUTH credentials at:"
    echo "https://console.cloud.google.com/apis/credentials?project=planet4-production&organizationId=644593243610"
    echo

    read -rp "Enter GA_CLIENT_ID: " ga_client_id
  fi
fi

#
# Encode GoogleApps Client Secret
#
ga_client_secret=${GA_CLIENT_SECRET:-}
if [[ -z "$ga_client_secret" ]]
then
  if [[ "$use_existing_credentials" =~ ^[yY] ]]
  then
    set +e
    ga_client_secret=$(jq -r '.ga_clientsecret' <<<"$option")
    set -e
  fi

  if [ -z "$ga_client_secret" ]
  then
    read -rsp "Enter GA_CLIENT_SECRET: " ga_client_secret
  fi

  echo
fi

echo
echo "---"
echo
echo "Release:    $release"
echo "$release" > HELM_RELEASE
echo "Namespace:  $namespace"
echo "$namespace" > HELM_NAMESPACE
echo "Redis:      $redis"
echo "$redis" > REDIS_SERVICE
echo "GA Client:  ${ga_client_id//}"
echo "$ga_client_id" | openssl base64 -a -A > GA_CLIENT_ID
echo "$ga_client_secret" | openssl base64 -a -A > GA_CLIENT_SECRET
echo
read -rp "Do these values look correct? [y/N] " yn
echo
case $yn in
    [Yy]* ) echo "Configuration OK.";;
    * ) echo "Clearing configuration files ...";
        echo "Please run ./configure.sh again";
        rm HELM_RELEASE HELM_NAMESPACE REDIS_SERVICE GA_CLIENT_ID GA_CLIENT_SECRET;
        exit 1 ;;
esac
echo
echo "Run \`make\` to perform the processes"
