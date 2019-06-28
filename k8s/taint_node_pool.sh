#!/usr/bin/env bash
set -eu

nodepool=$1

taint=$2

echo "Tainting nodes in nodepool '$nodepool' with taint '$taint':"

nodes=$(kubectl get nodes -l cloud.google.com/gke-nodepool="$nodepool" -o=name)
echo "${nodes[@]}"

echo
read -rp "Does this look good? [y/N] " yn
case "$yn" in
    [Yy]* ) : ;;
    * ) exit 1;;
esac

kubectl taint node -l cloud.google.com/gke-nodepool="$nodepool" "$taint" --overwrite
