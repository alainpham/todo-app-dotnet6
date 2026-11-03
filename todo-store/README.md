# todo-store

In-memory todo store for [todo-front](../todo-front), pinned to **.NET 6.0.36 / ASP.NET Core 6.0.36** like the frontend.
todo-front serves the UI and forwards every `/api/todos` call here over plain HTTP, giving a two-service chain
(`todo-front → todo-store`) to test how Beyla connects traces between services.

## Endpoints (port 7124)
| Method & path | Description |
|---|---|
| `GET /api/todos` | List todos |
| `GET /api/todos/{id}` | Get one todo |
| `POST /api/todos` | Create: `{"title": "..."}` |
| `PUT /api/todos/{id}` | Update: `{"title": "...", "done": true}` (both optional) |
| `DELETE /api/todos/{id}` | Delete |
| `GET /healthz` | health probe |

Data is kept in memory only: it is lost on restart, and each pod has its own list, so the Deployment runs a single replica.

## Build and push
```bash
docker build -t reg.k.codersandbox.com/todo-store:latest .
docker push reg.k.codersandbox.com/todo-store:latest
```

## Deploy to Kubernetes
Deploys into the `apps` namespace as Service `todo-store` (port 80), which todo-front reaches at `http://todo-store`.
Create the namespace first (or just run `../deploy.sh`):
```bash
kubectl create namespace apps --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f k8s/deployment.yaml
kubectl -n apps rollout status deploy/todo-store
```

## Run locally with todo-front
```bash
docker network create todo
docker run -d --rm --name todo-store --network todo reg.k.codersandbox.com/todo-store:latest
docker run --rm --network todo -p 7123:7123 -e TODO_STORE_URL=http://todo-store:7124 reg.k.codersandbox.com/todo-front:latest
open http://localhost:7123/
```

## Cleanup
```bash
kubectl delete -f k8s/deployment.yaml
```
