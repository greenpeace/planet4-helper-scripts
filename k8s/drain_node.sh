#!/usr/bin/env bash
set -euo pipefail

node=$1
grace=${2:-30}

kubectl get nodes
echo

[[ -n ${FORCE_DRAIN:-} ]] || {
  read -rp "Drain node '$node'? [y/N] " yn
  case "$yn" in
      [Yy]* ) : ;;
      * ) exit 1;;
  esac
}

echo
echo " >> Draining ${node#node\/} ..."
set -x
time kubectl drain --force --ignore-daemonsets --delete-local-data --grace-period="${grace}" "${node}"
{ set +x; } 2>/dev/null
echo
date
