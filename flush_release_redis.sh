#!/usr/bin/env bash
set -eu

echo ""
echo "============================================================================="
echo ""

release=${1:-${HELM_RELEASE}}
echo "Release:    $release"

namespace=${2:-${HELM_NAMESPACE:-$(./get_namespace.sh $release)}}
if ! kubectl get namespace $namespace > /dev/null
then
  echo "ERROR: Namespace '$namespace' not found."
  exit 1
fi
echo "Namespace:  $namespace"

#
# Set kubectl command to use the discovered namespace
#
kc="kubectl -n $namespace"

redis=${3:-${REDIS_SERVICE:-$(helm status $release | grep redis | grep Running | head -n1 | cut -d' ' -f1)}}
echo "Redis:      $redis"
echo ""

# Check if interactive
if tty -s
then
  read -p "Flush redis cache? [y/N] " yn
  echo ""
  case $yn in
      [Yy]* ) $kc exec $redis -- redis-cli flushdb ;;
      * ) echo "WARNING: Skipping redis flush, any changes may not be visible." ;;
  esac
else
  $kc exec $redis -- redis-cli flushdb
fi
