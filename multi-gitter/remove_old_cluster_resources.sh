#!/bin/bash
set -euo pipefail
env=$1
if [ "$env" == "dev" ]; then
	gcloud container clusters get-credentials p4-development --project planet-4-151612
	helm ls -n develop --output=json | jq -r '.[].name' | xargs -n 1 echo "helm uninstall -n develop"
elif [ "$env" == "stage" ]; then
	gcloud container clusters get-credentials p4-production --zone us-central1-a --project planet4-production
	helm ls -A --output=json | jq '.[] | select(.chart|test("^wordpress.+")) | select(.name|test("^planet4-.+?-release")) | .namespace, .name' | xargs -n 2 echo "helm delete -n"
elif [ "$env" == "prod" ]; then
	gcloud container clusters get-credentials p4-production --zone us-central1-a --project planet4-production
	helm ls -A --output=json | jq '.[] | select(.chart|test("^wordpress.+")) | select(.name|test("^planet4-.+?-master")) | .namespace, .name' | xargs -n 2 echo "helm delete -n"
fi
