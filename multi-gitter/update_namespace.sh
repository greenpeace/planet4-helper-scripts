#!/bin/bash

set -euo pipefail
repo=${REPOSITORY#"greenpeace/planet4-"}

pushd .circleci
#yq -i '.job_environments.develop_environment.HELM_NAMESPACE = "'"${repo}"'"' config.yml
yq -i '.job_environments.release_environment.HELM_NAMESPACE = "'"${repo}"'-staging"' config.yml
# yq -i '.job_environments.production_environment.HELM_NAMESPACE = "'"${repo}"'"' config.yml
popd
