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
SERVICE_ACCOUNT_LIST=/tmp/service_account.lst
ROLES_LIST=/tmp/roles.lst
STORAGE_ADMIN_MEMBERS=/tmp/storage_admin_members.lst
BUCKET_LIST=/tmp/bucket.lst

function get_buckets {
  NRO=$(echo $1 | cut -d@ -f1)
  RESULT=($(cat ${BUCKET_LIST} | grep ${NRO}))
  echo ${RESULT[*]}
}

function remove_bucket_level_role {
 # this function will apply a role to a bucket
 sa="$1"
 bucket="$2"
 control=0

 bindings_file="/tmp/bindings.jq"
 echo "sa=$sa bucket=$bucket"
 # save a temporary file with bindings for the current bucket
 gsutil iam get ${bucket} | jq .bindings > ${bindings_file}
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
       echo "=> ${sa} is a member of role ${member_of}, removing..."
       # REMOVE IT
       control=1
       break
     else
       control=0
     fi
   else
     control=0
   fi
 done

 if [ ${control} -eq 1 ]
 then
   # sa is not a member of roles/storage.admin - adding it
   echo "removing ${sa} membership of roles/storage.admin"
   gsutil iam ch -d serviceAccount:${sa}:roles/storage.admin ${bucket}
   if [ $? -eq 0 ]
   then
     echo "=> removed ${sa} membership of roles/storage.admin"
   else
     echo "=> ERROR: could not remove ${sa} as membership of roles/storage.admin - aborting"
     exit 1
   fi
 fi
}

function set_storage_admin_role {
  sa=$1
  project=$2
  # check if $sa member of roles/storage.admin
  grep -q ${sa} ${STORAGE_ADMIN_MEMBERS}
  if [ $? -eq 0 ]
  then
    echo "=> ${sa} is already a member of ${project} roles/storage.admin"
  else
    echo "adding $sa as ${project} roles/storage.admin member"
    gcloud projects add-iam-policy-binding ${project} --member=serviceAccount:${sa} --role=roles/storage.admin 2>&1
  fi
}

# generate a listing of service accounts
echo "Please wait - generating service account and bucket listing"
gcloud iam service-accounts list --project planet-4-151612 --format json | jq .[].email | tr -d \" > ${SERVICE_ACCOUNT_LIST}
gsutil ls > ${BUCKET_LIST}
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

if [ "${SERVICE_ACCOUNT}" == "all" ]
then
 echo "this will update permissions for all service accounts"
 read  -p "type \"yes\" to confirm: " CONTINUE
 if [ "${CONTINUE}" == "yes" ]
 then
  while IFS= read -r sa
  do
    # only run set_storage_admin_role if role existsgcloud iam service-accounts list --format json | jq .[].email | grep brazil
    [ -f ${STORAGE_ADMIN_MEMBERS} ] && set_storage_admin_role ${sa} ${PROJECT}
    echo "Checking buckets for ${sa}"
    sa_buckets=($(get_buckets ${sa}))
    # get the sa_buckets_array lenght
    len=${#sa_buckets[@]}
    if [ ${len} -ge 1 ]
    then
      echo "found buckets for ${sa}:"
      echo ${sa_buckets[*]}
      for i in "${sa_buckets[@]}"
      do
        remove_bucket_level_role ${sa} $i
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
  sa=$(cat ${SERVICE_ACCOUNT_LIST} | grep ${SERVICE_ACCOUNT} )
  # only run set_storage_admin_role if role exists
  [ -f ${STORAGE_ADMIN_MEMBERS} ] && set_storage_admin_role ${sa} ${PROJECT}
  sa_buckets=($(get_buckets ${sa}))
  len=${#sa_buckets[@]}
  if [ ${len} -ge 1 ]
  then
    echo "found buckets for ${sa}:"
    echo ${sa_buckets[*]}
    for i in "${sa_buckets[@]}"
    do
      remove_bucket_level_role ${sa} $i
    done
  fi
  return=0
fi

rm -f ${SERVICE_ACCOUNT_LIST} ${BUCKET_LIST} ${ROLES_LIST} ${STORAGE_ADMIN_MEMBERS}
exit ${return}
