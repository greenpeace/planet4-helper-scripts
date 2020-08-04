#!/usr/bin/env bash
#set -x
set -eo pipefail
RED='\033[1;31m'
GREEN='\033[1;32m'
NC='\033[0m' # No Color

echo
read -rp "Enter node you have cordoned: " remove_node
echo
echo "This is the node we will be restarting pods on: $remove_node "

printf '\nRestarting P4 Redis stateful sets ...\n'

for i in $(kubectl get pods -A -o wide | grep "$remove_node" | grep ' planet4-' | grep redis | awk -F '-redis' '{print $1}' | awk -F 'planet4-' '{print $2}')
do
  echo " $i ..."
  ns=$(kubectl get pods -A | grep -w "$i" |cut -d' ' -f1 | sort -u)
  kubectl rollout restart -n "$ns" statefulset/planet4-"$i"-redis-master
  sleep 10
done

printf '\nWaiting for 1 minute for restarts to complete ...\n'
sleep 60

printf '\nRestarting P4 Wordpress Openresty deployments ...\n'

for i in $(kubectl get pods -A -o wide | grep "$remove_node" | grep wordpress-openresty \
| awk -F '-wordpress' '{print $1}' | awk -F 'planet4-' '{print $2}')
do
  echo " $i ..."
  ns=$(kubectl get pods -A | grep -w "$i" |cut -d' ' -f1 | sort -u)
  kubectl rollout restart -n "$ns" deployment/planet4-"$i"-wordpress-openresty
  sleep 10
done

printf '\nWaiting for 1 minute for restarts to complete ...\n'
sleep 60

printf '\nRestarting P4 Wordpress PHP deployments ...\n'

for i in $(kubectl get pods -A -o wide | grep "$remove_node" | grep wordpress-php \
 | awk -F '-wordpress' '{print $1}' | awk -F 'planet4-' '{print $2}')
do
  echo " $i ..."
  ns=$(kubectl get pods -A | grep -w "$i" |cut -d' ' -f1 | sort -u)
  kubectl rollout restart -n "$ns" deployment/planet4-"$i"-wordpress-php
  sleep 10
done

printf '\nWaiting for 1 minute for restarts to complete ...\n'
sleep 60

printf '\nChecking restarted pods are OK ...\n'

for i in $(kubectl get pods -A -o wide | grep "$remove_node" | grep wordpress \
  | awk -F '-wordpress' '{print $1}' | awk -F 'planet4-' '{print $2}' | sort -u )
do
  echo " $i ..."
  if
  ns=$(kubectl get pods -A | grep -w "$i" |cut -d' ' -f1 | sort -u )
  url=$(kubectl get ingress -n "$ns" planet4-"$i"-wordpress-openresty \
    -o=jsonpath='{.spec.rules[:1].host}{.spec.rules[:1].http.paths[:1].path}')
  curl -fsSI  "https://$url" &>/dev/null
  then
    echo -e "https://$url" "${GREEN}OK${NC}"
  else echo -e "https://$url" "${RED}FAIL${NC}"
  fi
done
