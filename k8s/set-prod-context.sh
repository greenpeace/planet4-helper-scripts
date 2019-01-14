#!/usr/bin/env bash
set -eu

namespace=$1

cluster=gke_planet4-production_us-central1-a_planet4-production
user=gke_planet4-production_us-central1-a_planet4-production

kubectl config set-context planet4-${namespace}-master \
 --namespace $namespace \
 --cluster $cluster \
 --user $user
