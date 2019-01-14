#!/usr/bin/env bash
set -eu

nodepool=$1

echo "Draining nodes in nodepool '$nodepool' ..."
#
# for node in $(kubectl get nodes -l cloud.google.com/gke-nodepool="$nodepool" -o=name)
# do
#   kubectl cordon "$node"
# done

kubectl get nodes

for node in $(kubectl get nodes -l cloud.google.com/gke-nodepool="$nodepool" -o=name)
do
  kubectl drain --force --ignore-daemonsets --delete-local-data --grace-period=10 "$node" &
done

pause
