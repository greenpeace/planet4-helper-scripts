#!/usr/bin/env bash
set -euo pipefail

release=$1

kubectl get pods --all-namespaces -l release=$release -o json | jq -r '.items[].metadata.namespace' | uniq