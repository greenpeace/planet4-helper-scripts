#!/usr/bin/env bash

set -eauo pipefail
RED='\033[1;31m'
GREEN='\033[1;32m'
NC='\033[0m' # No Color

PS3="Please select K8 P4 Development or P4 Production: "
select name in Development Production
do
  case "$name" in
    Development)
      kube_env=$(kubectx gke_planet-4-151612_us-central1-a_p4-development)
      gcloud config set project planet-4-151612
      break
      ;;
    Production)
      kube_env=$(kubectx gke_planet4-production_us-central1-a_planet4-production)
      gcloud config set project planet4-production
      break
      ;;
  esac
done
project=$(gcloud config get-value project)
echo "K8 Environment:   $kube_env"
echo "Project:          $project"
echo

cluster=${1:-${GKE_CLUSTER:-$(gcloud config get-value container/cluster 2>/dev/null)}}
[ -z "$cluster" ] && {
  echo
  gcloud container clusters list --project="$project"
  echo
  read -rp "Confirm cluster name: " cluster
}
echo "Cluster:   $cluster"

if [ $cluster = planet4-production ]
then
  echo -e "\n You are in ${RED} PRODUCTION ${NC}\n"
  PS3="Please select a deployment environment: "
  select name in Staging Production
  do
    case "$name" in
      Staging)
        deployenv=release
        break
        ;;
      Production)
        deployenv=master
        break
        ;;
    esac
  done
else
  deployenv=development
fi
echo "Deployment Environment:   $deployenv"

nro=
[ -z "$nro" ] && {
  printf  '\nIf you just want to restart one NRO please enter here, otherwise ALL deployments are restarted\n'
  read -rp "Enter NRO or deployment name: " nro
}
echo "Restarting:   $nro"

printf '\nRestarting P4 Redis stateful sets, if cordoned they will move to a new node pool ...\n'
if [ -z "$nro" ]
then
  if [ $deployenv = development ]; then
    for i in $(kgp -A |grep redis |cut -d' ' -f1)
    do
      echo " $i ..."
      kubectl rollout restart -n develop statefulset/planet4-"$1"-redis-master
    done
  else
    for i in $(kgp -A |grep $deployenv |grep redis |cut -d' ' -f1)
    do
      echo " $i ..."
      kubectl rollout restart -n "$1" statefulset/planet4-"$1"-$deployenv-redis-master
    done
  fi
  kubectl get pod -A -l app=redis -o wide | grep $deployenv
  sleep 60
else
  if [ $deployenv = development ]; then
    kubectl rollout restart -n develop statefulset/planet4-"$nro"-redis-master
  else
    kubectl rollout restart -n "$nro" statefulset/planet4-"$nro"-"$deployenv"-redis-master
  fi
  kubectl get pod -A -l app=redis -o wide | grep "$nro" | grep $deployenv
fi


printf '\nRestarting P4 Wordpress deployments, if cordoned they will move to a new node pool ...\n'
if [ -z "$nro" ]
then
  if [ $deployenv = development ]; then
    for i in $(kgp -A |grep wordpress |cut -d' ' -f1 | sort -u)
    do
      echo " $i ..."
      kubectl rollout restart -n develop deployment/planet4-"$1"-wordpress-openresty
      kubectl rollout restart -n develop deployment/planet4-"$1"-wordpress-php
    done
  else
    for i in $(kgp -A |grep $deployenv |grep wordpress |cut -d' ' -f1 | sort -u)
    do
      echo " $i ..."
      kubectl rollout restart -n "$1" deployment/planet4-"$1"-"$deployenv"-wordpress-openresty
      kubectl rollout restart -n "$1" deployment/planet4-"$1"-"$deployenv"-wordpress-php
    done
  fi
  kubectl get pod -A -l app=planet4 -o wide | grep "$deployenv"
  sleep 5
else
  if [ $deployenv = development ]; then
    kubectl rollout restart -n develop deployment/planet4-"$nro"-wordpress-openresty
    kubectl rollout restart -n develop deployment/planet4-"$nro"-wordpress-php
  else
    kubectl rollout restart -n "$nro" deployment/planet4-"$nro"-"$deployenv"-wordpress-openresty
    kubectl rollout restart -n "$nro" deployment/planet4-"$nro"-"$deployenv"-wordpress-php
  fi
  kubectl get pod -A -l app=planet4 -o wide | grep "$nro" | grep "$deployenv"
fi

printf '\nChecking everything has restarted successfully ... wait 1 minute for things to restart \n'
sleep 60
if [ -z "$nro" ]
then
  for i in $(kgp -A |grep wordpress |cut -d' ' -f1 | sort -u)
  do
    echo " $i ..."
    if [ $deployenv = development ]; then
      curl -fsSI "https://k8s.p4.greenpeace.org/$1/" &>/dev/null &&
      echo -e "$1" "${GREEN}OK${NC}" || echo -e "$1" "${RED}FAIL${NC}"
    elif [ $deployenv = release ]; then
      curl -fsSI  "https://$deployenv.k8s.p4.greenpeace.org/$1/" &>/dev/null &&
      echo -e "$1" "${GREEN}OK${NC}" || echo -e "$1" "${RED}FAIL${NC}"
    elif [ $deployenv = master ]; then
      curl -fsSI  "https://greenpeace.org/$1/" &>/dev/null &&
      echo -e "$1" "${GREEN}OK${NC}" || echo -e "$1" "${RED}FAIL${NC}"
    fi
  done
else
  if [ $deployenv = development ]; then
    curl -fsSI "https://k8s.p4.greenpeace.org/$nro/" &>/dev/null &&
    echo -e "$nro" "${GREEN}OK${NC}" || echo -e "$nro" "${RED}FAIL${NC}"
  elif [ $deployenv = release ]; then
    curl -fsSI "https://$deployenv.k8s.p4.greenpeace.org/$nro/" &>/dev/null &&
    echo -e "$nro" "${GREEN}OK${NC}" || echo -e "$nro" "${RED}FAIL${NC}"
  elif [ $deployenv = master ]; then
    curl -fsSI "https://greenpeace.org/$nro/" &>/dev/null &&
    echo -e "$nro" "${GREEN}OK${NC}" || echo -e "$nro" "${RED}FAIL${NC}"
  fi
fi
