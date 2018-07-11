#!/usr/bin/env bash
set -eu

function usage {
  echo "Usage:

  $(basename "$0") <planet4-release-name> [<redis_servicename>]

Example:

  $(basename "$0") planet4-flibble-release

If <redis_servicename> is not set, the Helm binary is required to detect the
redis servicename. See https://helm.sh

"
}

if [[ -z "${1:-}" ]]
then
  >&2 echo "Error: Release name not set"
  >&2 echo
  usage
  exit 1
fi

release=$1

#
# Determine namespace from release
#
namespace=$(./get-namespace.sh $release)
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

# =============================================================================
#
# Perform database backup before operations
#
echo ""
echo "========================================================================="
echo ""
read -p "Backup database for $release? [y/N] " yn
case $yn in
    [Yy]* ) ./backup_release_db.sh $release ;;
    * ) : ;;
esac

# =============================================================================
#
# Replace all instances of defaultcontent with new path
#
echo ""
echo "============================================================================="
echo ""
oldpath=${OLD_PATH:-planet4-defaultcontent-stateless-develop}
path=$($kc get pod $pod -o yaml | grep -A 1 WP_STATELESS_MEDIA_BUCKET | grep value | cut -d: -f 2 | xargs)
echo "Replacing path references:"
echo "Old path:       /$oldpath"
echo "New path:       /$path"
echo ""

$kc exec $pod -- wp search-replace $oldpath $path --dry-run --precise --skip-columns=guid

echo ""
read -p "Apply path changes? [y/N] " yn
echo ""
case $yn in
    [Yy]* ) $kc exec $pod -- wp search-replace $oldpath $path --precise --skip-columns=guid ;;
    * ) echo "Skipping... " ;;
esac

echo ""
echo "============================================================================="
echo ""

./flush_release_redis.sh $release
