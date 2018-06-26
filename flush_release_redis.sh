#!/usr/bin/env bash
set -eu

release=$1
echo "Release:    $release"

#
# Determine namespace from release
#
namespace=$(helm status $release | grep NAMESPACE: | cut -d: -f2 | xargs)
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

echo ""
echo "============================================================================="
echo ""
redis=$(helm status $release | grep redis | grep Running | head -n1 | cut -d' ' -f1)
echo "Pod:        $redis"
echo ""
read -p "Flush redis cache? [y/N] " yn
echo ""
case $yn in
    [Yy]* ) $kc exec $redis -- redis-cli flushdb ;;
    * ) echo "WARNING: Skipping redis flush, any changes may not be visible." ;;
esac
