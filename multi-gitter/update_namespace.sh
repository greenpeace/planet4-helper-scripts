#!/bin/bash

set -euxo pipefail

# create `repo` var without greenpeace/planet-4 prefix
repo=${REPOSITORY#"greenpeace/planet4-"}

# change to .circleci directory
pushd .circleci

# update HELM_NAMESPACE in config.yml

## development env 
## namespace will e.g. be changed from `development` to `argentina`
#yq -i '.job_environments.develop_environment.HELM_NAMESPACE = "'"${repo}"'"' config.yml

## staging env
## namespace will e.g. be changed from `argentina-release` to `argentina-staging`
yq -i '.job_environments.release_environment.HELM_NAMESPACE = "'"${repo}"'-staging"' config.yml

## production env
## namespace will e.g. be changed from `argentina-release` to `argentina`
#yq -i '.job_environments.production_environment.HELM_NAMESPACE = "'"${repo}"'"' config.yml

# change back to start directory
popd

# find current and new version of the tag/releases
#current_version=$(git describe --abbrev=0 --tags)
current_version=$(git tag --sort=-creatordate | head -1)
#current_version=$(git tag --sort=-v:refname | head -1)
new_version=$(perl -pe 's/^(v?(\d+\.)*)(\d+)(.*)$/$1.($3+1).$4/e' <<<"$current_version")

echo "=========="
echo " Tagging new release for ${repo} - ${new_version}"
echo "=========="

# tag new version and push to circleci to create new production workflow
git commit -a --allow-empty -m 'PLANET-6884: Update namespace variables to bring dev and staging in line with production'
git tag -a "$new_version" -m "$new_version"
git push origin --tags