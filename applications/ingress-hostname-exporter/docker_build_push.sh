#!/bin/bash

# Exit immediately if a command fails
set -e

# Ask the user for the image name and tag
read -p "Enter Docker image tag (e.g., v1.0.0): " IMAGE_TAG

FULL_IMAGE="harbor.yuriy-lab.cloud/library/ingress-hostname-exporter:${IMAGE_TAG}"

echo "Building Docker image: $FULL_IMAGE..."

# Build the Docker image
docker buildx build --platform linux/amd64 -t "$FULL_IMAGE" -f dockerfile .


echo "Docker image built successfully: $FULL_IMAGE"

# Ask for confirmation to push
read -p "Do you want to push the image to the registry? (y/N): " CONFIRM

if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Pushing Docker image: $FULL_IMAGE..."
    docker push "$FULL_IMAGE"
    echo "Docker image pushed successfully!"
else
    echo "Push canceled. You can push later with: docker push $FULL_IMAGE"
fi
