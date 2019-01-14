#!/usr/bin/env bash
set -eu

context=$1

kubectl config use-context $context
