#!/usr/bin/env bash
set -eu

DEVELOP_DOMAIN=k8s.p4.greenpeace.org
RELEASE_DOMAIN=release.k8s.p4.greenpeace.org
MASTER_DOMAIN=master.k8s.p4.greenpeace.org
PRODUCTION_DOMAIN=www.greenpeace.org

#
# Pass release in as the first argument
#
release=${1:-${HELM_RELEASE}}
echo "Release:    $release"

#
# Determine namespace from release
#
namespace=${2:-${HELM_NAMESPACE:-$(./get_namespace.sh $release)}}
if ! kubectl get namespace "$namespace" > /dev/null
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
pod=$($kc get pods \
    --sort-by=.metadata.creationTimestamp \
    --field-selector=status.phase=Running \
    -l "app=planet4,release=${release},component=php" \
    -o jsonpath="{.items[-1:].metadata.name}")

echo "Pod:        $pod"

# =============================================================================
#
# Perform database backup before operations
#
echo ""
echo "========================================================================="
echo ""
read -rp "Backup database for $release? [Y/n] " yn
case $yn in
    [Nn]* ) : ;;
    * ) ./backup_release_db.sh "$release" ;;
esac

function search_replace {
    search=$1
    replace=$2
    path=${3:-$APP_HOSTPATH}

    echo ""
    echo "============================================================================="
    echo ""

    wp_search_replace "$search" "$replace"

}

function wp_search_replace {
  $kc exec "$pod" -- wp search-replace "$1" "$2" --dry-run --all-tables --precise --skip-columns=guid

  echo ""
  echo "Search:     $1"
  echo "Replace:    $2"
  echo ""

  read -rp "Apply changes? [y/N] " yn
  case $yn in
      [Yy]* ) $kc exec -ti "$pod" -- wp search-replace "$1" "$2" --all-tables --precise --skip-columns=guid ;;
      * ) echo "Skipping... " ;;
  esac
}

function db_search_replace {
  >&2 echo "Unused function: db_search_replace"
  # $kc exec "$pod" -- wp search-replace "$1" "$2" --dry-run --all-tables --precise --skip-columns=guid
  #
  # echo ""
  # echo "Search:     $1"
  # echo "Replace:    $2"
  # echo ""
  #
  # read -rp "Apply changes? [y/N] " yn
  # case $yn in
  #     [Yy]* ) $kc exec -ti "$pod" -- wp search-replace "$1" "$2" --all-tables --precise --skip-columns=guid ;;
  #     * ) echo "Skipping... " ;;
  # esac
}

# =============================================================================
#
# Update stateless bucket
#
echo ""
echo "============================================================================="
echo ""
oldbucket=${OLD_BUCKET:-planet4-defaultcontent-stateless-develop}
newbucket=$($kc get pod "$pod" -o yaml | grep -A 1 WP_STATELESS_MEDIA_BUCKET | grep value | cut -d: -f 2 | xargs)
echo "Replacing bucket references:"
echo "Old bucket:     '$oldbucket'"
echo "New bucket:     '$newbucket'"
echo ""

wp_search_replace "$oldbucket" "$newbucket"

# =============================================================================
#
# Replace defaultcontent with new path
#
echo ""
echo "============================================================================="
echo ""
oldpath=${OLD_PATH:-defaultcontent}
APP_HOSTPATH=$($kc get pod "$pod" -o yaml | grep -A 1 APP_HOSTPATH | grep value | cut -d: -f 2 | xargs)
export APP_HOSTPATH

echo "Replacing path references:"
echo "Old path:       '$oldpath'"
echo "New path:       '$APP_HOSTPATH'"
echo ""

wp_search_replace "$oldpath" "$APP_HOSTPATH"

# =============================================================================
#
# Replace all instances of master.k8s.p4.greenpeace.org with new domain
#
function do_release_domain {
  search_replace $DEVELOP_DOMAIN $RELEASE_DOMAIN
}

# =============================================================================
#
# Replace all instances of [release.]k8s.p4.greenpeace.org with new domain
#
function do_master_domain {
  search_replace $RELEASE_DOMAIN $MASTER_DOMAIN
  search_replace $DEVELOP_DOMAIN $MASTER_DOMAIN
}

# =============================================================================
#
# Replace all instances of [release.|master.]k8s.p4.greenpeace.org with new domain
#
function do_production_domain {
  search_replace $RELEASE_DOMAIN $PRODUCTION_DOMAIN
  search_replace $MASTER_DOMAIN $PRODUCTION_DOMAIN
  search_replace $DEVELOP_DOMAIN $PRODUCTION_DOMAIN
}

# =============================================================================
#
# Replace all instances of [release.|master.]k8s.p4.greenpeace.org with new domain
#
function do_custom_domain {

  new_domain=${1:-}
  if [[ -z "$new_domain" ]]
  then
    read -rp "Enter new domain: " new_domain
  fi

  # Remove any leading protocol string
  new_domain=${new_domain%"http://"}
  new_domain=${new_domain%"https://"}

  search_replace $RELEASE_DOMAIN "$new_domain"
  search_replace $MASTER_DOMAIN "$new_domain"
  search_replace $DEVELOP_DOMAIN "$new_domain"
}

# =============================================================================
#
# Attempt to detect domain automatically
#
echo ""
echo "============================================================================="
echo ""
new_domain=$($kc describe pod "$pod" | grep APP_HOSTNAME | cut -d: -f2 | xargs)
read -rp "Update DB domain to: $new_domain [y/N] ? " automated_domain
case $automated_domain in
  y ) do_custom_domain "$new_domain" && exit 0 ;;
  * ) : ;;
esac

# =============================================================================
#
# Choose which domain replacement to perform
#
echo ""
echo "============================================================================="
echo ""
echo "Select new domain:"
echo ""
echo " 1 - Release domain
     (replaces https://k8s.p4.greenpeace.org with ${RELEASE_DOMAIN})"
echo " 2 - Master domain
     (replaces https://[release.]k8s.p4.greenpeace.org with ${MASTER_DOMAIN})"
echo " 3 - Production domain
     (replaces https://[release|master.]k8s.p4.greenpeace.org with ${PRODUCTION_DOMAIN})"
echo " 4 - Custom domain
     (replaces https://[release|master.]k8s.p4.greenpeace.org with custom domain)"
echo ""
read -rp "Release type? [1/2/3/4] " release_type
echo ""
case $release_type in
  1 ) do_release_domain ;;
  2 ) do_master_domain ;;
  3 ) do_production_domain ;;
  4 ) do_custom_domain ;;
  * ) echo "Skipping domain changes..." ;;
esac
