#!/usr/bin/env bash
set -eu

openssl enc -base64 -a -A <&0
