#!/usr/bin/env bash
set -eu

nodepool=$1

project=${GCP_PROJECT:-$(gcloud config get-value project)}
[ -z "$project" ] && {
  read -rp "Enter GCP project: " project
}
echo "Project:   $project"

cluster=${2:-${GKE_CLUSTER:-$(gcloud config get-value container/cluster 2>/dev/null)}}
[ -z "$cluster" ] && {
  echo
  gcloud container clusters list --project="$project"
  echo
  read -rp "Enter cluster name: " cluster
}
echo "Cluster:   $cluster"

echo
gcloud container node-pools describe "$nodepool" --cluster="$cluster" --project="$project"
echo

echo "Deleting nodepool '$nodepool':"
echo

nodes=$(kubectl get nodes -l cloud.google.com/gke-nodepool="$nodepool" -o=name)
echo "${nodes[@]}"

echo
read -rp "Does this look good? [y/N] " yn
case "$yn" in
    [Yy]* ) : ;;
    * ) exit 1;;
esac

gcloud container node-pools delete --cluster="$cluster" --project="$project"
