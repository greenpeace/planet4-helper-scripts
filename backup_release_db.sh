#!/usr/bin/env bash
set -eu

release=$1

namespace=$(echo $release | cut -d- -f2)
if ! kubectl get namespace $namespace
then
  echo "ERROR: Namespace '$namespace' not found."
  exit 1
fi
echo "Namespace:  $namespace"

# Set kubernetes command with namespace
kc="kubectl -n $namespace"

pod=$($kc get pods -l component=php | grep $release | head -n1 | cut -d' ' -f1)
echo "Pod:        $pod"

datestring=$(date -u +"%Y%m%dT%H%M%SZ")

$kc exec -ti $pod -- wp db export backup-$datestring.sql

$kc cp $pod:backup-$datestring.sql "$release-$datestring".sql
echo ""
echo "File downloaded: $release-$datestring.sql"
echo ""
