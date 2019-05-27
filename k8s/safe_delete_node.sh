#!/usr/bin/env bash
set -euo pipefail

node=$1

FORCE_DRAIN=1 ./drain_node.sh "$node"

time kubectl delete node "$node"
