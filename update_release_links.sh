#!/usr/bin/env bash
set -eu

DEVELOP_DOMAIN=k8s.p4.greenpeace.org
RELEASE_DOMAIN=release.k8s.p4.greenpeace.org
MASTER_DOMAIN=master.k8s.p4.greenpeace.org
PRODUCTION_DOMAIN=www.greenpeace.org

#
# Pass release in as the first argument
#
release=$1
echo "Release:    $release"

#
# Determine namespace from release
#
namespace=${2:-$(./get_namespace.sh $release)}
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
read -p "Backup database for $release? [Y/n] " yn
case $yn in
    [Nn]* ) : ;;
    * ) ./backup_release_db.sh $release ;;
esac

# =============================================================================
#
# Replace all instances of defaultcontent with new path
#
echo ""
echo "============================================================================="
echo ""
oldpath=${OLD_PATH:-defaultcontent}
path=$($kc get pod $pod -o yaml | grep -A 1 APP_HOSTPATH | grep value | cut -d: -f 2 | xargs)
echo "Replacing path references:"
echo "Old path:       $oldpath"
echo "New path:       $path"
echo ""

$kc exec $pod -- wp search-replace $oldpath $path --dry-run --all-tables --precise --skip-columns=guid
echo ""
read -p "Apply path changes? [y/N] " yn
echo ""
case $yn in
    [Yy]* ) $kc exec $pod -- wp search-replace $oldpath $path --all-tables --precise --skip-columns=guid ;;
    * ) echo "Skipping... " ;;
esac

function wp_search_replace {
    search=$1
    replace=$2

    echo ""
    echo "============================================================================="
    echo ""

    $kc exec $pod -- wp search-replace "$search" "$replace" --dry-run --all-tables --precise --skip-columns=guid

    echo ""
    echo "Search:     $search"
    echo "Replace:    $replace"
    echo ""

    read -p "Apply domain changes? [y/N] " yn
    case $yn in
        [Yy]* ) $kc exec -ti $pod -- wp search-replace "$search" "$replace" --all-tables --precise --skip-columns=guid ;;
        * ) echo "Skipping... " ;;
    esac

    OLD_DOMAIN=$search \
    NEW_DOMAIN=$replace \
    SITE_PATH=$path \
    dockerize -template new.sql.tmpl:new.sql

    echo
    cat new.sql
    echo

    read -p "Apply SQL? [y/N] " yn
    case $yn in
        [Yy]* ) $kc cp new.sql $pod:new.sql; $kc exec -ti $pod -- wp db import new.sql ;;
        * ) echo "Skipping... " ;;
    esac

}

# =============================================================================
#
# Replace all instances of master.k8s.p4.greenpeace.org with new domain
#
function do_release_domain {
  wp_search_replace $DEVELOP_DOMAIN $RELEASE_DOMAIN
}

# =============================================================================
#
# Replace all instances of [release.]k8s.p4.greenpeace.org with new domain
#
function do_master_domain {
  wp_search_replace $RELEASE_DOMAIN $MASTER_DOMAIN
  wp_search_replace $DEVELOP_DOMAIN $MASTER_DOMAIN

}

# =============================================================================
#
# Replace all instances of [release.|master.]k8s.p4.greenpeace.org with new domain
#
function do_production_domain {
  wp_search_replace $RELEASE_DOMAIN $PRODUCTION_DOMAIN
  wp_search_replace $MASTER_DOMAIN $PRODUCTION_DOMAIN
  wp_search_replace $DEVELOP_DOMAIN $PRODUCTION_DOMAIN

}

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
     (replaces https://k8s.p4.greenpeace.org with https://release.k8s.p4.greenpeace.org)"
echo " 2 - Master domain
     (replaces https://[release.]k8s.p4.greenpeace.org with https://master.k8s.p4.greenpeace.org)"
echo " 3 - Production domain
     (replaces https://[release|master.]k8s.p4.greenpeace.org with https://www.greenpeace.org)"
echo ""
read -p "Release type? [1/2/3] " release_type
echo ""
case $release_type in
  1 ) do_release_domain ;;
  2 ) do_master_domain ;;
  3 ) do_production_domain ;;
  * ) echo "Skipping domain changes..." ;;
esac
