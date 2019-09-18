#!/usr/bin/env bash
# shellcheck disable=SC2086
set -euo pipefail

node_version=${NODE_VERSION:-latest}

echo

if [ $node_version = "latest" ]; then
  echo "Using latest available node version"
  node_version_param=""
else
  echo "Using node version: $node_version"
  node_version_param="--node-version=$node_version "
fi

echo

cluster=${1:-${GKE_CLUSTER:-$(gcloud config get-value container/cluster 2>/dev/null)}}
project=${GCP_PROJECT:-$(gcloud config get-value project)}

node_pool=${2:-${NODE_POOL:-}}


[ -z "$project" ] && {
  read -rp "Enter GCP project: " project
}
echo "Project:   $project"

[ -z "$cluster" ] && {
  echo
  gcloud container clusters list --project="$project"
  echo
  read -rp "Enter cluster name: " cluster
}
echo "Cluster:   $cluster"

[ -z "$node_pool" ] && {
  echo
  gcloud container node-pools list --project=$project --cluster=$cluster
  echo
  read -rp "Enter new node-pool name: " node_pool
  echo
}

disk_size=${DISK_SIZE:-200}
machine_type=${MACHINE_TYPE:-n1-standard-4}

min_nodes=${MIN_NODES:-10}
max_nodes=${MAX_NODES:-20}

num_nodes=${NUM_NODES:-${min_nodes}}

zone=${ZONE:-us-central1-a}

scopes=${SCOPES:-gke-default,https://www.googleapis.com/auth/ndev.clouddns.readwrite}

echo "node_version: $node_version"

echo "machine:   $machine_type"
echo "zone:      $zone"
echo "disk_size: $disk_size"
echo "num_nodes: $num_nodes"
echo "min_nodes: $min_nodes"
echo "max_nodes: $max_nodes"
echo "scopes:    $scopes"
echo

echo "AUTO UPGRADE IS DISABLED! Fix P4 then remove this line and enable auto-upgrading nodepools!"

echo
read -rp "Create new nodepool named '$node_pool' ? [y/N] " yn
case "$yn" in
    [Yy] ) : ;;
    * ) exit 1;;
esac

gcloud container node-pools create "$node_pool" \
  --no-enable-autoupgrade \
  --project=$project \
  --cluster=$cluster \
  --zone=$zone \
  $node_version_param \
  --machine-type=$machine_type \
  --disk-size=$disk_size \
  --enable-autoscaling \
  --no-enable-autoupgrade \
  --num-nodes=$num_nodes \
  --min-nodes=$min_nodes \
  --max-nodes=$max_nodes \
  --scopes $scopes

echo "Success"
echo
