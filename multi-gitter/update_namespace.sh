#!/bin/bash

set -euo pipefail
repo=${REPOSITORY#"greenpeace/planet4-"}

pushd .circleci
#yq -i '.job_environments.develop_environment.HELM_NAMESPACE = "'"${repo}"'"' config.yml
yq -i '.job_environments.release_environment.HELM_NAMESPACE = "'"${repo}"'-staging"' config.yml
#yq -i '.job_environments.production_environment.HELM_NAMESPACE = "'"${repo}"'"' config.yml
popd

current_version=$(git describe --abbrev=0 --tags)
new_version=$(perl -pe 's/^(v?(\d+\.)*)(\d+)(.*)$/$1.($3+1).$4/e' <<<"$current_version")
git tag -a "$new_version" -m "$new_version"
git push origin --tags