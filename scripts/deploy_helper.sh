#!/usr/bin/env bash
set -e

ENV=$1
IMAGE=$2

if [ -z "$ENV" ] || [ -z "$IMAGE" ]; then
  echo "Usage: $0 <env> <image>"
  exit 1
fi

echo "🚀 Deploying ${IMAGE} to ${ENV} namespace..."

# Update image in deployment
sed -i "s|REPLACE_WITH_IMAGE|${IMAGE}|g" k8s/${ENV}/deployment.yaml

# Apply manifests
kubectl apply -f k8s/${ENV}/ -n ${ENV}

echo "✅ Deployment complete for ${ENV}"

