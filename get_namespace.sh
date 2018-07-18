#!/usr/bin/env bash
set -euo pipefail

release=$1

helm status $release | grep NAMESPACE: | cut -d' ' -f2 | sed 's/planet4-//' | sed 's/-master$//' | sed 's/-release$//' | xargs
