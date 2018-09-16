#!/usr/bin/env bash
set -eux

name=$1

cluster=${2:-$CLUSTER}
disk_size=${DISK_SIZE:-200GB}
machine_type=${MACHINE_TYPE:-n1-standard-4}

num_nodes=${NUM_NODES:-4}

min_nodes=${MIN_NODES:-3}
max_nodes=${MAX_NODES:-10}
zone=${ZONE:-us-central1-a}

gcloud container node-pools create $name \
  --cluster=$cluster \
  --disk-size=$disk_size \
  --machine_type=$machine_type \
  --num-nodes=$num_nodes \
  --min-nodes=$min_nodes \
  --max-nodes=$max_nodes \
  --zone=$zone \
  --enable-autoscaling
