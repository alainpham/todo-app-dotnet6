# todo-front

Minimal ASP.NET Core 6 todo app frontend (plain HTML/JS UI), pinned to **.NET 6.0.36 / ASP.NET Core 6.0.36** (file version 6.0.3624.51604).

## Endpoints
| Method & path | Description |
|---|---|
| `GET /` | Todo UI (`src/HelloWorld/wwwroot/index.html`) |
| `GET /api/todos` | List todos |
| `GET /api/todos/{id}` | Get one todo |
| `POST /api/todos` | Create: `{"title": "..."}` |
| `PUT /api/todos/{id}` | Update: `{"title": "...", "done": true}` (both optional) |
| `DELETE /api/todos/{id}` | Delete |
| `GET /healthz` | health probe |

The todos are stored by [todo-store](../todo-store): every `/api/todos` call is forwarded over plain HTTP to `TODO_STORE_URL`
(default `http://todo-store`), so a request goes `browser → todo-front → todo-store`. If todo-store is unreachable the API returns `502`.

## Build the image
```bash
docker build -t todo-front:latest .
```
To run it locally it needs todo-store; see [todo-store/README.md](../todo-store/README.md#run-locally-with-todo-front).

## Push to the registry
`k8s/deployment.yaml` pulls `reg.k.codersandbox.com/todo-front:latest`:
```bash
docker tag todo-front:latest reg.k.codersandbox.com/todo-front:latest
docker push reg.k.codersandbox.com/todo-front:latest
curl https://reg.k.codersandbox.com/v2/todo-front/tags/list
```
The manifests use `imagePullPolicy: Always`, so a new push of `latest` is picked up on the next pod restart (`kubectl -n apps rollout restart deploy/todo-front`). Or run `../build-push.sh && ../deploy.sh` to build, push and redeploy both services.

## Deploy to Kubernetes
```bash
kubectl create namespace apps --dry-run=client -o yaml | kubectl apply -f -   # not in the manifests, so cleanup never deletes it
kubectl apply -f k8s/deployment.yaml
kubectl apply -f ../todo-store/k8s/deployment.yaml
kubectl -n apps rollout status deploy/todo-front
kubectl -n apps port-forward svc/todo-front 7123:80
open http://localhost:7123/
```

## Synthetic traffic
`k8s/traffic.yaml` runs a curl loop that every 5 seconds creates a todo through the `todo-front` Service and deletes the one created 5 seconds earlier, so each request exercises `todo-front → todo-store`:
```bash
kubectl apply -f k8s/traffic.yaml
kubectl -n apps logs -f deploy/todo-front-traffic
kubectl delete -f k8s/traffic.yaml   # stop it
```

## Cleanup
```bash
kubectl delete -f k8s/traffic.yaml
kubectl delete -f ../todo-store/k8s/deployment.yaml
kubectl delete -f k8s/deployment.yaml
```
