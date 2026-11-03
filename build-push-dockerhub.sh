#!/bin/sh
# Build todo-front and todo-store and push them to Docker Hub as alainpham/<project>.
# Usage: ./build-push-dockerhub.sh [tag]   (default tag: latest)
# Requires `docker login` beforehand.
set -eu

cd "$(dirname "$0")"

TAG="${1:-latest}"
NAMESPACE="alainpham"

for project in todo-front todo-store; do
  image="$NAMESPACE/$project:$TAG"

  echo "==> Building $image"
  docker build -t "$image" "$project"

  echo "==> Pushing $image"
  docker push "$image"
done

echo "==> Done: pushed $NAMESPACE/todo-front:$TAG and $NAMESPACE/todo-store:$TAG"
