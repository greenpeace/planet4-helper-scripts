#!/usr/bin/env bash
#set -x
set -euo pipefail
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

printf '\n You are about to restart all non-P4 site deployments'
printf '\n'
read -p "Press enter to continue"

printf '\nRestarting non-P4 deployments, if cordoned they will move to a new node pool ...\n'
 for i in $(kubectl get deployments -A --selector 'app notin (planet4,traefik)' | awk '{print $2}' | tail -n +2)
    do
      echo " $i ..."
      ns=$(kubectl get deployments -A --selector 'app notin (planet4,traefik)' | grep $i | awk '{print $1}' | head -1 )
      kubectl rollout restart -n "$ns" deployment/"$i"
      printf '\n ... wait 10 seconds for things to restart \n'
      sleep 10
      kubectl get pod -A -o wide | grep "$i"
    done  

printf '\n You are about to restart all non-P4 site stateful sets'
printf '\n'
read -p "Press enter to continue"

printf '\nRestarting non-P4 stateful sets, if cordoned they will move to a new node pool ...\n'
 for i in $(kubectl get statefulsets -A --selector=app!=redis | awk '{print $2}' | tail -n +2)
    do
      echo " $i ..."
      ns=$(kubectl get statefulsets -A --selector=app!=redis | grep $i | awk '{print $1}' | head -1 )
      kubectl rollout restart -n "$ns" statefulset/"$i" 
      printf '\n ... wait 10 seconds for things to restart \n'
      sleep 10
      kubectl get pod -A -o wide | grep "$i"
    done  
