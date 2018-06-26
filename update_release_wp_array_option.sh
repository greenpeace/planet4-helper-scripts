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

#
# Find the first php pod in the release
#
pod=$($kc get pods -l component=php | grep $release | head -n1 | cut -d' ' -f1)
echo "Pod:        $pod"
echo ""
echo "Option:     $option_name"
echo "Key:        $option_key"
echo "Value:      $option_value"
echo ""

old=$($kc exec $pod -- wp option get ${option_name} --format=json)
echo ""
echo $old
echo ""
new=$(php -r "
\$option = json_decode( '$old' );
\$option->${option_key} = \"${option_value}\";
print json_encode(\$option);
")

echo ""
echo $new
echo ""

read -p "Apply changes? [y/N] " yn
case $yn in
    [Yy]* ) $kc exec $pod -- wp option set ${option_name} $new --format=json ;;
    * ) echo "Skipping... " ;;
esac
