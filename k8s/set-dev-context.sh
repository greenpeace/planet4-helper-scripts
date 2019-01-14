#!/usr/bin/env bash
set -eu

namespace=$1

cluster=gke_planet-4-151612_us-central1-a_p4-development
user=gke_planet-4-151612_us-central1-a_p4-development

kubectl config set-context planet4-${namespace}-develop \
 --namespace $namespace \
 --cluster $cluster \
 --user $user
