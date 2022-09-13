# Generate Repolist

`REPO_ARRAY=$(helm3 ls -A --output=json | jq '[.[] | select(.chart|test("^wordpress.+"))] | map(.name |= "greenpeace/\(.)") | [.[].name]')  yq -i '.repo = $REPO_ARRAY' config.yml`

After running this command a CI pipeline for each sites development environment will be deployed. You can run the `./remove_old_cluster_resources.sh <dev|stage|prod`
