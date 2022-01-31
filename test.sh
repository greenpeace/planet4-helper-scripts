#!/bin/bash
SERVICE_ACCOUNT="test-nix"
if [[ "${SERVICE_ACCOUNT}" == *"test"* ]]; then SERVICE_ACCOUNT="${SERVICE_ACCOUNT//-}"; fi
echo "SA ${SERVICE_ACCOUNT}"
bucket_name=${SERVICE_ACCOUNT//test/test-}
echo "Bucket: ${bucket_name}"