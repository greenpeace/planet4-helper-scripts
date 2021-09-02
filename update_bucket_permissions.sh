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
       echo "${sa} is already member of role ${member_of}"
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
   gsutil iam ch serviceAccount:${sa}:roles/storage.admin ${bucket}
   if [ $? -eq 0 ]
   then
     echo "added ${sa} as member of roles/storage.admin"
   else
     echo "ERROR: could not add ${sa} as member of roles/storage.admin - aborting"
     exit 1
   fi
 fi
}

function remove_storage_admin_role {
  sa=$1
  echo "not yet - removing storage admin role from ${sa} service account"
}

# generate a listing of service accounts
echo "Please wait - generating service account and bucket listing"
gcloud iam service-accounts list --project planet-4-151612 --format json | jq .[].email | tr -d \" > ${SERVICE_ACCOUNT_LIST}
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
        echo "set_bucket_level_role ${sa} $i"
      done
      # remove_storage_admin_role ${sa}
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
  sa_buckets=($(get_buckets ${sa}))
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
  fi
  remove_storage_admin_role ${sa}
  return=0
fi

rm -f ${SERVICE_ACCOUNT_LIST} ${BUCKET_LIST}
exit ${return}
