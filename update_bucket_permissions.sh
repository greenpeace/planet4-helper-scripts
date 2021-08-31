#!/usr/bin/env bash
set -eu

function usage {
  echo "Usage: $(basename "$0") nro_name"
}

if [[ -z "${1:-}" ]]
then
  usage
  exit 1
fi

SERVICE_ACCOUNT=$1
SERVICE_ACCOUNT_LIST=/tmp/service_account.lst
BUCKET_LIST=/tmp/bucket.lst

function get_buckets {
  NRO=$(echo $1 | cut -d@ -f1)
  RESULT=($(cat ${BUCKET_LIST} | grep ${NRO}))
  echo ${RESULT[*]}
}

function set_bucket_level_role {
 # this function will apply a role to a bucket
 bucket=$1
 echo "for now just echoing: ${bucket}"
}

# generate a listing of service accounts
echo "Please wait - generating service account and bucket listing"
gcloud iam service-accounts list --format json | jq .[].email | tr -d \" > ${SERVICE_ACCOUNT_LIST}
gsutil ls > ${BUCKET_LIST}

if [ "${SERVICE_ACCOUNT}" == "all" ]
then
 echo "this will update permissions for all service accounts"
 read  -p "type \"yes\" to confirm: " CONTINUE
 if [ "${CONTINUE}" == "yes" ]
 then
  while IFS= read -r sa
  do
    echo "Checking buckets for ${sa}"
    sa_buckets=($(get_buckets ${sa}))
    # get the sa_buckets_array lenght
    len=${#sa_buckets[@]}
    if [ ${len} -ge 1 ]
    then
      # here we can add a fucntion to  check and assign permissions on bucket
      # also check and remove Storage Admin role
      echo "found buckets for ${sa}:"
      echo ${sa_buckets[*]}
      for i in "${sa_buckets[@]}"
      do
        echo "applying role to $i"
        set_bucket_level_role "$i"
      done
    fi
  done < "${SERVICE_ACCOUNT_LIST}"
  return=0
 else
   echo "aborting"
   return=1
 fi
else
  # create an array of buckets that belongs to SERVICE_ACCOUNT
  sa_buckets=($(get_buckets ${SERVICE_ACCOUNT}))
  len=${#sa_buckets[@]}
  if [ ${len} -ge 1 ]
  then
    # here we can add a function to check and assign permissions on bucket
    # also check and remove Storage Admin role
    echo "found buckets for ${SERVICE_ACCOUNT}:"
    echo ${sa_buckets[*]}
    echo "applying new role"
    for i in "${sa_buckets[@]}"
    do
      echo "applying role to $i"
      set_bucket_level_role "$i"
    done
  fi
  unset ${sa_buckets}
  return=0
fi

rm -f ${SERVICE_ACCOUNT_LIST} ${BUCKET_LIST}
exit ${return}
