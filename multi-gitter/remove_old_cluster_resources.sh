#!/bin/bash
set -euo pipefail
env=$1
if [ "$env" == "dev" ]; then
	gcloud container clusters get-credentials p4-development --project planet-4-151612
	while read -r resource; do 
  		helm uninstall -n develop "$resource"
  		/usr/bin/multi-gitter run --config=config.yml --repo="greenpeace/$resource" ./update_namespace.sh
	done < <(helm ls -n develop --output=json | jq -r '.[].name')
elif [ "$env" == "staging" ]; then
	gcloud container clusters get-credentials planet4-production --zone us-central1-a --project planet4-production
	while read -r resource; do 
		helm uninstall -n "$resource"
		resource2=$(echo "$resource" | cut -d " " -f2 | cut -d "-" -f1,2)
		/usr/bin/multi-gitter run --config=config.yml --repo=greenpeace/"${resource2}" ./update_namespace.sh
	done < <(helm ls -a --all-namespaces | grep "release" | awk 'NR > 1 { print  $2, $1}')
fi