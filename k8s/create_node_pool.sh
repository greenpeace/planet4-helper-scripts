#!/usr/bin/env bash
# shellcheck disable=SC2086
set -eux

name=$1

cluster=${2:-$CLUSTER}
disk_size=${DISK_SIZE:-200}
machine_type=${MACHINE_TYPE:-n1-standard-4}

num_nodes=${NUM_NODES:-4}

min_nodes=${MIN_NODES:-3}
max_nodes=${MAX_NODES:-10}
zone=${ZONE:-us-central1-a}

gcloud container node-pools create "$name" \
  --cluster=$cluster \
  --zone=$zone \
  --machine-type=$machine_type \
  --disk-size=$disk_size \
  --enable-autoscaling \
  --num-nodes=$num_nodes \
  --min-nodes=$min_nodes \
  --max-nodes=$max_nodes
