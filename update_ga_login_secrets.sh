#!/usr/bin/env bash
set -eu

release=$1

read -s -p "Client ID: " client_id
echo
read -s -p "Client Secret: " client_secret
echo

./update_release_wp_array_option.sh $release galogin ga_clientid $client_id
./update_release_wp_array_option.sh $release galogin ga_clientsecret $client_secret

./flush_release_redis.sh $release
