#!/usr/bin/env bash
set -euo pipefail
docker build -f docker/Dockerfile -t canary-demo:stable --build-arg APP_VERSION=stable .
docker build -f docker/Dockerfile -t canary-demo:canary --build-arg APP_VERSION=canary .
echo "Built canary-demo:stable and canary-demo:canary"
