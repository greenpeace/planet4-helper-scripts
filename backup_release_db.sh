#!/usr/bin/env bash
set -eu

release=$1

namespace=$(./get_namespace.sh "$release")
if ! kubectl get namespace "$namespace" > /dev/null
then
  echo "ERROR: Namespace '$namespace' not found."
  exit 1
fi
echo "Namespace:  $namespace"

# Set kubernetes command with namespace
kc="kubectl -n $namespace"

pod=$($kc get pods -l component=php | grep "$release" | head -n1 | cut -d' ' -f1)
echo "Pod:        $pod"

datestring=$(date -u +"%Y%m%dT%H%M%SZ")

$kc exec -ti "$pod" -- wp db export "backup-$datestring.sql"

mkdir -p backup

$kc cp "$pod:backup-$datestring.sql" "backup/$release-$datestring.sql"
echo ""
echo "File downloaded: $release-$datestring.sql"
echo ""
