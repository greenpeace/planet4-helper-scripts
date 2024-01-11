#!/usr/bin/env bash
set -o pipefail

# What do I want to acheive in this script?
# Assign cors per https://cloud.google.com/storage/docs/configuring-cors
# https://jira.greenpeace.org/browse/PLANET-4692
#1. Get the right google project

SITE_ENV=$1
mkdir -p /tmp/cors
LOG_FILE=/tmp/cors/"$SITE_ENV"_configure_cors.txt
CORS_JSON_FILE=cors-json-file.json


if [ -z "$1" ]
then echo "Please enter environment ie. develop, release or master"
  exit 0
fi

if SITE_ENV="develop"
then
  GOOGLE_PROJECT_ID="planet-4-151612"
  RELEASE="develop"
  BUCKET_TAG="stateless-develop"
elif SITE_ENV="release"
then
  GOOGLE_PROJECT_ID="planet4-production"
  RELEASE="release"
  BUCKET_TAG="stateless-release"
else
  GOOGLE_PROJECT_ID="planet4-production"
  RELEASE="master"
  BUCKET_TAG="stateless"
fi

#2. Get a list of stateful set buckets for that project

gcloud config set project $GOOGLE_PROJECT_ID
echo $GOOGLE_PROJECT_ID
echo $BUCKET_TAG

gcloud storage ls ls | grep $BUCKET_TAG >> bucket_list

#2b. Check if any CORS settings already exist, if so skip ?

while read -r BUCKET_NAME
do
  echo "Checking for existing CORS configuration in $BUCKET_NAME"
  gcloud storage buckets describe $BUCKET_NAME --format="default(cors_config)" >> "$RELEASE"_corsconfig_current 2>&1
done < bucket_list
rm bucket_list

grep "has no CORS configuration" "$RELEASE"_corsconfig_current | cut -d ' ' -f1 > "$RELEASE"_corsconfig_action

#3a. Test json config file exists:  cors-json-file.json

if [ ! -f "$CORS_JSON_FILE" ]
then
  echo "File $CORS_JSON_FILE does not exist, rename bak file"
  exit 1
fi

#3. Enable CORS based on the json file that accompanies this script

while read -r BUCKET_NAME
do
  echo "Applying CORS configuration per $CORS_JSON_FILE and "$RELEASE"_corsconfig_action"
  gcloud storage buckets update $BUCKET_NAME --cors-file=$CORS_JSON_FILE >> $LOG_FILE 2>&1
done < "$RELEASE"_corsconfig_action
