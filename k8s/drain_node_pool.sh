#!/usr/bin/env bash
set -euo pipefail

nodepool=$1
sleep=${2:-120}

nodes=$(kubectl get nodes -l cloud.google.com/gke-nodepool="$nodepool" -o=name)
num=$(echo "$nodes" | wc -l)

echo
echo "Draining nodes in nodepool '$nodepool':"
echo
echo "${nodes[@]}"
echo "$num total"

echo
read -rp "Does this look good? [y/N] " yn
case "$yn" in
    [Yy]* ) : ;;
    * ) exit 1;;
esac

i=0
for node in $nodes
do
  echo
  i=$(( i + 1 ))
  echo " $i/$num >> Cordoning ${node#node\/} ..."
  kubectl cordon "${node}"
done
echo

i=0
for node in $nodes
do
  echo
  i=$(( i + 1 ))
  echo " $i/$num >> Draining ${node#node\/} ..."
  time kubectl drain --force --ignore-daemonsets --delete-local-data --grace-period=30 "${node}"
  echo
  date
  [[ $i < $num ]] && {
    printf "Waiting %ds for things to calm down ... (press any key to continue) " ${sleep}
    # shellcheck disable=SC2034
    set +e
    # shellcheck disable=SC2034
    read -rt "${sleep}" -s -n 1 answer && echo "... interrupted!"
    set -e
  }
done
