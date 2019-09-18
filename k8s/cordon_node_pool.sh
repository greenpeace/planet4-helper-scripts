#!/usr/bin/env bash
set -eu

nodepool=$1


echo "Cordoning nodes in nodepool '$nodepool':"

nodes=$(kubectl get nodes -l cloud.google.com/gke-nodepool="$nodepool" -o=name)
echo "${nodes[@]}"

echo
read -rp "Continue? [y/N] " yn
case "$yn" in
    [Yy]* ) : ;;
    * ) exit 1;;
esac

for node in $nodes
do
  kubectl cordon "$node"
done

echo
