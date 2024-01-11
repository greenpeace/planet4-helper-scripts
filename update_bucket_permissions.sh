#!/bin/bash

function usage {
  echo "Usage: $(basename "$0") nro_name"
}

if [[ -z "${1:-}" ]]
then
  usage
  exit 1
fi

SERVICE_ACCOUNT=$1
skip_sas=(
  "planet-4-151612@appspot.gserviceaccount.com" 
  "stateless-nikos-test-plane-158@planet-4-151612.iam.gserviceaccount.com"
  )
SERVICE_ACCOUNT_LIST=/tmp/service_account.lst
ROLES_LIST=/tmp/roles.lst
STORAGE_ADMIN_MEMBERS=/tmp/storage_admin_members.lst
BUCKET_LIST=/tmp/bucket.lst

function get_buckets {
  NRO=$(echo $1 | cut -d@ -f1)
  RESULT=($(cat ${BUCKET_LIST} | grep ${NRO}))
  echo ${RESULT[*]}
}

function set_bucket_level_role {
 # this function will apply a role to a bucket
 sa="$1"
 bucket="$2"
 control=0

 bindings_file="/tmp/bindings.jq"
 echo "sa=$sa bucket=$bucket"
 # save a temporary file with bindings for the current bucket
 gcloud storage buckets get-iam-policy ${bucket} --format json | jq .bindings > ${bindings_file}
 # get the lenght of bindigs array
 bindigs_length=$(cat ${bindings_file} | jq 'length' )
 # check if sa is member of any role
 for ((i=0; i<${bindigs_length} ; i++))
 do
   # first check if sa is member of any role
   cat "${bindings_file}" | jq .[$i].members | grep "${sa}"
   if [ $? = 0 ]
   then
     member_of=$(cat ${bindings_file} | jq .[$i].role)
     # is sa memberof roles/storage.admin ?
     if [ "${member_of}" == "\"roles/storage.admin\"" ]
     then
       echo "=> ${sa} is already member of role ${member_of}"
       control=0
       break
     else
       control=1
     fi
   else
     control=1
   fi
 done

 if [ ${control} -eq 1 ]
 then
   # sa is not a member of roles/storage.admin - adding it
   echo "adding ${sa} as member of roles/storage.admin"
   gcloud storage buckets set-iam-policy-binding ${bucket} --member=serviceAccount:${sa} --role=roles/storage.admin
   if [ $? -eq 0 ]
   then
     echo "=> added ${sa} as member of roles/storage.admin"
   else
     echo "=> ERROR: could not add ${sa} as member of roles/storage.admin - aborting"
     exit 1
   fi
 fi
}

function remove_storage_admin_role {
  sa=$1
  project=$2
  # check if $sa member of roles/storage.admin
  grep -q ${sa} ${STORAGE_ADMIN_MEMBERS}
  if [ $? -eq 0 ]
  then
    echo "removing ${sa} from roles/storage.admin"
    echo "and project ${project}"
    gcloud projects remove-iam-policy-binding ${project} --member=serviceAccount:${sa} --role=roles/storage.admin 2>&1
  else
    echo "=> $sa is not a ${project} roles/storage.admin member"
  fi
}

# generate a listing of service accounts
echo "Please wait - generating service account and bucket listing"
gcloud iam service-accounts list --project planet-4-151612 --format json | jq .[].email | tr -d \" > ${SERVICE_ACCOUNT_LIST}
gcloud storage ls > ${BUCKET_LIST}
# get current project
PROJECT=$(gcloud config get-value project)
# genereate a role index of iam policy
gcloud projects get-iam-policy ${PROJECT} --format=json | jq .bindings | grep role > ${ROLES_LIST}
# check if roles/storage.admin exists
grep -q storage.admin ${ROLES_LIST}
if [ $? -eq 0 ]
then
  # get project roles/storage.admin members
  i=$(grep -n storage.admin ${ROLES_LIST} | cut -f1 -d:)
  i=$((i-1))
  gcloud projects get-iam-policy ${PROJECT} --format=json | jq .bindings[${i}].members > ${STORAGE_ADMIN_MEMBERS}
fi

echo "Service account before processing: ${SERVICE_ACCOUNT}"
if [[ "${SERVICE_ACCOUNT}" == *"test"* ]]; then SERVICE_ACCOUNT="${SERVICE_ACCOUNT//-}"; fi
echo "Service account after processing: ${SERVICE_ACCOUNT}"

if [ "${SERVICE_ACCOUNT}" == "all" ]
then
 echo "this will update permissions for all service accounts"
 read  -p "type \"yes\" to confirm: " CONTINUE
 if [ "${CONTINUE}" == "yes" ]
 then
  while IFS= read -r sa
  do
    if [[ "${skip_sas[*]}" =~ "${sa}" ]]; then
     echo "Skipping: ${sa} because it is in the skip list"
     continue
    fi
    echo "Checking buckets for ${sa}"
    bucket_name=${sa//test/test-}
    sa_buckets=($(get_buckets ${bucket_name}))
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
        set_bucket_level_role ${sa} $i
      done
      # only run remove_storage_admin_role if role actually exists
      [ -f ${STORAGE_ADMIN_MEMBERS} ] && remove_storage_admin_role "${sa}" "${PROJECT}"
    fi
  done < "${SERVICE_ACCOUNT_LIST}"
  return=0
 else
   echo "aborting"
   return=1
 fi
else
  # create an array of buckets that belongs to SERVICE_ACCOUNT
  sa=$(cat ${SERVICE_ACCOUNT_LIST} | grep "${SERVICE_ACCOUNT}" )
  bucket_name=${sa//test/test-}
  sa_buckets=($(get_buckets ${bucket_name}))
  len=${#sa_buckets[@]}
  if [ ${len} -ge 1 ]
  then
    echo "found buckets for ${sa}:"
    echo ${sa_buckets[*]}
    echo "applying new role"
    for i in "${sa_buckets[@]}"
    do
      echo "applying role to $i"
      set_bucket_level_role ${sa} $i
    done
  else
    echo "warning: no buckets found from ${sa}"
  fi
  # only run remove_storage_admin_role if role actually exists
  [ -f ${STORAGE_ADMIN_MEMBERS} ] && remove_storage_admin_role ${sa} ${PROJECT}
  return=0
fi

rm -f ${SERVICE_ACCOUNT_LIST} ${BUCKET_LIST} ${ROLES_LIST} ${STORAGE_ADMIN_MEMBERS}
exit ${return}
