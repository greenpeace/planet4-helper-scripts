#!/bin/bash
set -euo pipefail

# pick up given environment var (dev/staging/production)
env=$1
## development env
if [ "$env" == "dev" ]; then
	# get credentials to authenticate
	gcloud container clusters get-credentials p4-development --project planet-4-151612
	# read `$resource`
	while read -r resource; do 
		# uninstall the helm release
  		helm uninstall -n develop "$resource"
		# run helm-gitter to update the HELM_NAMESPACE in the git repository
  		/usr/bin/multi-gitter run --config=config.yml --repo="greenpeace/$resource" ./update_namespace.sh
	# pipe in the helm listing in development namespace and [].name to be used as `resource`
	done < <(helm ls -n develop --output=json | jq -r '.[].name')
## staging env
elif [ "$env" == "staging" ]; then
	# get credentials to authenticate
	gcloud container clusters get-credentials planet4-production --zone us-central1-a --project planet4-production
	# read `$resource`
	while read -r resource; do 
		# uninstall the helm release
		helm uninstall -n $resource
		# drop the namespace from the `resource` var and cut off -release from the helm release name so we get e.g. "planet4-argentina"
		resource2=$(echo "$resource" | cut -d " " -f2 | rev | cut -d '-' --complement -f 1 | rev)
		# run helm-gitter to update the HELM_NAMESPACE in the git repository and push a new tag/release
		/usr/bin/multi-gitter run --config=config.yml --repo=greenpeace/"${resource2}" ./update_namespace.sh
		echo "=========="
		echo " Just finished updating namespaces for ${resource2}"
		echo " Sleeping for 5 seconds"
		echo "=========="
		sleep 5
	# pipe in the helm listing. grep `release` and pick up the name/namespace and reverse them so we can use them for running `helm uninstall -n` on it
	done < <(helm ls -a --all-namespaces | grep -v "staging" | grep "release" | awk 'NR > 1 { print  $2, $1}')
## production env
elif [ "$env" == "production" ]; then
	# get credentials to authenticate
	gcloud container clusters get-credentials planet4-production --zone us-central1-a --project planet4-production
	# read `$resource`
	while read -r resource; do 
		# uninstall the helm release
		helm uninstall -n <<< echo "${resource}"
		# drop the namespace from the `resource` var and cut off -release from the helm release name so we get e.g. "planet4-argentina"
		resource2=$(echo "$resource" | cut -d " " -f2 | cut -d "-" -f1,2)
		# run helm-gitter to update the HELM_NAMESPACE in the git repository and push a new tag/release
		/usr/bin/multi-gitter run --config=config.yml --repo=greenpeace/"${resource2}" ./update_namespace.sh
		echo "=========="
		echo " Just finished updating namespaces for ${resource2}"
		echo " Sleeping for 5 seconds"
		echo "=========="
		sleep 5
	# pipe in the helm listing. grep `release` and pick up the name/namespace and reverse them so we can use them for running `helm uninstall -n` on it
	done < <(helm ls -a --all-namespaces | grep "master" | awk 'NR > 1 { print  $2, $1}')
fi