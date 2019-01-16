#!/usr/bin/env bash
set -eu

release=${1:-}

[[ -z "$release" ]] && {

  echo
  echo " > helm ls"
  echo
  helm ls
}

echo
echo "---"
echo

if [[ -z "$release" ]]
then
  read -rp "Enter Helm release: " release
fi
if ! helm status "$release"
then
  echo "ERROR: Release '$release' not found."
  exit 1
fi
#
# Determine namespace from release
#
namespace=${2:-$(./get_namespace.sh "$release")}
if ! kubectl get namespace "$namespace" > /dev/null
then
  echo "ERROR: Namespace '$namespace' not found."
  exit 1
fi
#
# Determine redis pod name
#
redis=${3:-$(kubectl get pods --namespace "${namespace}" \
    --field-selector=status.phase=Running \
    -l "app=redis,role=master,release=${release}" \
    -o jsonpath="{.items[0].metadata.name}")}

if ! kubectl -n "$namespace" get pod "$redis" > /dev/null
then
  echo "ERROR: Redis pod '$redis' not found."
  exit 1
fi

#
# Encode GoogleApps ClientID
#
echo "---"
echo
echo "Create Google Apps OAUTH credentials at:"
echo "https://console.cloud.google.com/apis/credentials?project=planet4-production&organizationId=644593243610"
echo
ga_client_id=${GA_CLIENT_ID:-}
if [[ -z "$ga_client_id" ]]
then
  read -rp "Enter GA_CLIENT_ID: " ga_client_id
fi

#
# Encode GoogleApps Client Secret
#
ga_client_secret=${GA_CLIENT_SECRET:-}
if [[ -z "$ga_client_secret" ]]
then
  read -rsp "Enter GA_CLIENT_SECRET: " ga_client_secret
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
