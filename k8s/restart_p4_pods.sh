#!/usr/bin/env bash
#set -x
set -euo pipefail
RED='\033[1;31m'
GREEN='\033[1;32m'
NC='\033[0m' # No Color
count=50

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

if [[ $project = planet4-production ]]
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

printf '\n If you just want to restart one NRO, enter the full name of the NRO'
printf '\n The full name is the CONTAINER_PREFIX without planet-4'
printf '\n'
read -rp "Enter NRO or deployment name here : " nro
echo "Restarting this NRO : " "$nro"

if [ -z "$nro" ]
then
  printf '\n If you want to start x number of deployments, enter the number here'
  printf '\n otherwise ALL deployments per environment are restarted'
  printf '\n'
  read -rp "Enter the number of deployments you want to restart : " count
  echo "Restarting this # of deployments : " "$count" "or ALL deployments"
fi

printf '\nRestarting P4 Redis stateful sets, if cordoned they will move to a new node pool ...\n'
if [ -z "$nro" ]
then
  if [[ $deployenv = development ]]; then
    for i in $(kubectl get pods -n develop | grep -m "$count" redis | awk -F '-redis' '{print $1}' | cut -c 9-)
    do
      echo " $i ..."
      kubectl rollout restart -n develop statefulset/planet4-"$i"-redis-master
    done
    kubectl get pod -n develop -o wide | grep redis
  else
    for i in $(kubectl get pods -A |grep $deployenv |grep -m "$count" redis |cut -d' ' -f1 | sort -u)
    do
      echo " $i ..."
      ns=$(kubectl get pods -A | grep "$i" |cut -d' ' -f1 | sort -u )
      kubectl rollout restart -n "$ns" statefulset/planet4-"$i"-"$deployenv"-redis-master
    done
    kubectl get pod -A -l app=redis -o wide | grep "$deployenv"
  fi
else
  if [[ $deployenv = development ]]; then
    kubectl rollout restart -n develop statefulset/planet4-"$nro"-redis-master
  else
    ns=$(kubectl get pods -A | grep "$nro" |cut -d' ' -f1 | sort -u )
    kubectl rollout restart -n "$ns" statefulset/planet4-"$nro"-"$deployenv"-redis-master
  fi
  kubectl get pod -A -l app=redis -o wide | grep "$nro" | grep "$deployenv"
fi

printf '\nRestarting P4 Wordpress deployments, if cordoned they will move to a new node pool ...\n'
if [ -z "$nro" ]
then
  if [[ $deployenv = development ]]; then
    for i in $(kubectl get pods -n develop | grep -m "$count" wordpress | /
    awk -F '-wordpress' '{print $1}' | cut -c 9-| sort -u)
    do
      echo " $i ..."
      kubectl rollout restart -n develop deployment/planet4-"$i"-wordpress-openresty
      kubectl rollout restart -n develop deployment/planet4-"$i"-wordpress-php
    done
    kubectl get pods -n develop -l app=planet4 -o wide
  else
    for i in $(kubectl get pod -A | grep "$deployenv" | grep -m "$count" wordpress | \
      awk -F '-wordpress' '{print $1}' | cut -c 29-| sort -u)
    do
      echo " $i ..."
      ns=$(kubectl get pods -A | grep "$i" |cut -d' ' -f1 | sort -u )
      kubectl rollout restart -n "$ns" deployment/planet4-"$i"-wordpress-openresty
      kubectl rollout restart -n "$ns" deployment/planet4-"$i"-wordpress-php
    done
    kubectl get pods -A -l app=planet4 -o wide | grep "$deployenv"
  fi
else
  if [[ $deployenv = development ]]; then
    kubectl rollout restart -n develop deployment/planet4-"$nro"-wordpress-openresty
    kubectl rollout restart -n develop deployment/planet4-"$nro"-wordpress-php
  else
    ns=$(kubectl get pods -A | grep "$nro" |cut -d' ' -f1 | sort -u )
    kubectl rollout restart -n "$ns" deployment/planet4-"$nro"-"$deployenv"-wordpress-openresty
    kubectl rollout restart -n "$ns" deployment/planet4-"$nro"-"$deployenv"-wordpress-php
  fi
  kubectl get pod -A -l app=planet4 -o wide | grep "$nro" | grep "$deployenv"
fi

printf '\nChecking everything has restarted successfully ... wait 1 minute for things to restart \n'
sleep 60
if [ -z "$nro" ]
then
  if [[ $deployenv = development ]]; then
    for i in $(kubectl get pods -n develop | grep -m "$count" wordpress | \
      awk -F '-wordpress' '{print $1}' | cut -c 9-| sort -u)
    do
      echo " $i ..."
      url=$(kubectl get ingress -n develop planet4-"$i"-wordpress-openresty \
        -o=jsonpath='{.spec.rules[:1].host}{.spec.rules[:1].http.paths[:1].path}')
      if curl -fsSI "https://$url" &>/dev/null; then
        echo -e "https://$url" "${GREEN}OK${NC}"
      else
        echo -e "https://$url" "${RED}FAIL${NC}"
      fi
    done
  else
    for i in $(kubectl get pod -A | grep "$deployenv" | grep -m "$count" wordpress | \
      awk -F '-wordpress' '{print $1}' | cut -c 29-| sort -u)
    do
      echo " $i ..."
      if
      ns=$(kubectl get pods -A | grep "$i" |cut -d' ' -f1 | sort -u )
      url=$(kubectl get ingress -n "$ns" planet4-"$i"-wordpress-openresty \
        -o=jsonpath='{.spec.rules[:1].host}{.spec.rules[:1].http.paths[:1].path}')
      curl -fsSI  "https://$url" &>/dev/null
      then
        echo -e "https://$url" "${GREEN}OK${NC}"
      else echo -e "https://$url" "${RED}FAIL${NC}"
      fi
    done
  fi
else
  if [[ $deployenv = development ]]; then
    if
    url=$(kubectl get ingress -n develop planet4-"$nro"-wordpress-openresty \
      -o=jsonpath='{.spec.rules[:1].host}{.spec.rules[:1].http.paths[:1].path}')
    curl -fsSI "https://$url/" &>/dev/null
    then
      echo -e "https://$url" "${GREEN}OK${NC}"
    else echo -e "https://$url" "${RED}FAIL${NC}"
    fi
  else
    if
    ns=$(kubectl get pods -A | grep "$nro" |cut -d' ' -f1 | sort -u )
    url=$(kubectl get ingress -n "$ns" planet4-"$nro"-"$deployenv"-wordpress-openresty \
      -o=jsonpath='{.spec.rules[:1].host}{.spec.rules[:1].http.paths[:1].path}')
    curl -fsSI  "https://$url" &>/dev/null
    then
      echo -e "https://$url" "${GREEN}OK${NC}"
    else echo -e "https://$url" "${RED}FAIL${NC}"
    fi
  fi
fi
