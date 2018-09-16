#!/usr/bin/env bash
set -eu

nodepool=$1

echo "Cordoning nodes in nodepool '$nodepool':"

for node in $(kubectl get nodes -l cloud.google.com/gke-nodepool=$nodepool -o=name)
do
  kubectl cordon "$node"
done
