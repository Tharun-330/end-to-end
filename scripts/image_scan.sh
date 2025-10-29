#!/bin/bash
set -euo pipefail
IMAGE=$1
if [ -z "$IMAGE" ]; then
  echo "Usage: $0 <image-uri>"
  exit 2
fi
echo "🔍 Scanning image: $IMAGE"
trivy image --exit-code 1 --severity HIGH,CRITICAL "$IMAGE"
