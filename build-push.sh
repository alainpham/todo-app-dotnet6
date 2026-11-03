#!/bin/sh
# Build todo-front and todo-store and push them to reg.k.codersandbox.com.
# Images are pushed as :latest (read from each project's k8s/deployment.yaml). The manifests use imagePullPolicy: Always,
# so `./deploy.sh` (which restarts the pods) picks up the new push.
set -eu

cd "$(dirname "$0")"

for project in todo-front todo-store; do
  image=$(sed -n 's/^ *image: *\(reg\.k\.codersandbox\.com\/[^ ]*\).*/\1/p' "$project/k8s/deployment.yaml" | head -n 1)
  if [ -z "$image" ]; then
    echo "ERROR: no reg.k.codersandbox.com image found in $project/k8s/deployment.yaml" >&2
    exit 1
  fi

  echo "==> Building $image"
  docker build -t "$image" "$project"

  echo "==> Pushing $image"
  docker push "$image"
done

echo "==> Registry tags"
curl -fsS https://reg.k.codersandbox.com/v2/todo-front/tags/list; echo
curl -fsS https://reg.k.codersandbox.com/v2/todo-store/tags/list; echo
