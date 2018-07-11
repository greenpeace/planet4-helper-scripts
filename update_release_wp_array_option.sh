#!/usr/bin/env bash
set -euo pipefail

# Updates a Wordpress array option
# See: https://wordpress.stackexchange.com/questions/267245/how-to-update-an-array-option-using-wp-cli
#
# Pass release in as the first argument
#
release=$1
echo "Release:    $release"

option_name=$2
option_key=$3
option_value=$4

#
# Determine namespace from release
#
namespace=$(./get_namespace.sh $release)
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

#
# Find the first php pod in the release
#
pod=$($kc get pods -l component=php | grep $release | head -n1 | cut -d' ' -f1)
echo "Pod:        $pod"
echo ""
echo "Option:     $option_name"
echo "Key:        $option_key"
# echo "Value:      $option_value"
echo ""

$kc exec $pod -- wp option patch update $option_name $option_key $option_value
