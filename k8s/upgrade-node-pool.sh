#!/usr/bin/env bash
set -eauo pipefail

project=${GCP_PROJECT:-$(gcloud config get-value project)}
[ -z "$project" ] && {
  read -rp "Enter GCP project: " project
}
echo "Project:   $project"

cluster=${1:-${GKE_CLUSTER:-$(gcloud config get-value container/cluster 2>/dev/null)}}
[ -z "$cluster" ] && {
  echo
  gcloud container clusters list --project="$project"
  echo
  read -rp "Enter cluster name: " cluster
}
echo "Cluster:   $cluster"

old_pool=${2:-}

[ -z "$old_pool" ] && {
  echo
  gcloud container node-pools list --project="$project" --cluster="$cluster"
  echo
  read -rp "Enter nodepool name to upgrade: " old_pool
  echo
}

n=${old_pool//[!0-9]/}
new_pool=pool-$(( n + 1 ))

read -rp "New node pool name: [$new_pool] " new_pool_answer
[ -z "$new_pool_answer" ] || new_pool=$new_pool_answer

echo "Upgrading nodepool '$old_pool' to '${new_pool}' ... "

current_state=$(gcloud container node-pools describe "$old_pool" --cluster="${cluster}" --project="${project}")

MIN_NODES=${MIN_NODES:-$(grep minNodeCount <<<"$current_state" | cut -d: -f2 | xargs)}
MAX_NODES=${MAX_NODES:-$(grep maxNodeCount <<<"$current_state" | cut -d: -f2 | xargs)}

# create new node pool

if [[ $(kubectl get node -l cloud.google.com/gke-nodepool="${new_pool}" -o name | wc -l | xargs) -lt 1 ]]
then
  ./create_node_pool.sh "$cluster" "$new_pool"
else
  echo "Nodepool '$new_pool' already exists, skipping ..."
fi

# taint nodes
./taint_node_pool.sh "$old_pool" upgrade=true:NoSchedule

# move ingress controller to new node pool
echo
echo "Moving ingress controller pods to new node pool ..."
for i in $(kubectl -n kube-system get pod -l app=traefik -o name)
do
  echo " $i ..."
  if kubectl -n kube-system get "$i" -o wide | grep -q "$new_pool"
  then
    echo "    ... SKIP: on new node-pool already"
    continue
  fi

  kubectl -n kube-system delete "$i"
  sleep 30
done

kubectl -n kube-system get pod -l app=traefik -o wide

read -rp "Continue ? " answer
case ${answer:0:1} in
    y|Y )
        echo Yes
    ;;
    * )
        echo No
        exit 1
    ;;
esac

# cordon nodes
./cordon_node_pool.sh "$old_pool"



# perform graceful p4 restart
echo "========================================================================="
echo
echo "Now is the time to restart the P4 applications"
echo
echo "Switch to another tab and run ./restart_p4_pods.sh"
echo
echo "Enter 'y' when all sites have been deployed."
echo

read -rp "Continue ? [y/N] " answer
case ${answer:0:1} in
    y|Y )
        echo Yes
    ;;
    * )
        echo No
        exit 1
    ;;
esac

# drain nodes
./drain_node_pool.sh "$old_pool"

./delete_node_pool.sh "$old_pool" "$cluster"
