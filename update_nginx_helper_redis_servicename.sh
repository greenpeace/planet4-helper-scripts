#!/usr/bin/env bash
set -eu

release=$1
redis_servicename=${2:-$(helm status $release | grep Service -A 10 | grep redis | head -n1 | cut -d' ' -f1)}

./update_release_wp_array_option.sh $release rt_wp_nginx_helper_options redis_hostname $redis_servicename

./flush_release_redis.sh $release
