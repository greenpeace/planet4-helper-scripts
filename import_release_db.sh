#!/usr/bin/env bash
set -euo pipefail

release=$1
echo "Release:    $release"

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

file=$2
if [[ ! -f "$file" ]]
then
  >&2 echo "File not found: $file"
  exit 1
fi
echo "File:       $file"

db=${3:-$(kubectl get pod "$pod" -o yaml | grep -A 1 MYSQL_DATABASE | grep value | cut -d: -f 2 | xargs)}
echo "Database:   $db"

echo "Copying $file to $pod:import.sql ..."
$kc cp "$file" "$pod:import.sql"

read -rp "Reset existing database? [y/N] " yn
case $yn in
    [Yy]* ) $kc exec "$pod" -- wp db reset --yes ;;
    * ) echo "Skipping... " ;;
esac

$kc exec "$pod" -- wp db import import.sql

$kc exec "$pod" -- rm -f import.sql
