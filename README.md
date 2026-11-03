# Capgemini observability demo

Two things live in this repo:

1. **A demo app** (`k8s/`): two small .NET 6 services, `todo-front` and `todo-store`, deployed to Kubernetes. They give a `browser → todo-front → todo-store` call chain to instrument and send to Grafana Cloud.
2. **An Alloy config** (`config.alloy`): a Windows host agent that collects host metrics, Windows event logs and OTLP telemetry, and forwards all of it to a gateway Alloy.

```
.
├── config.alloy                  # Grafana Alloy config for Windows hosts
└── k8s/
    ├── todo-front/               # ASP.NET Core 6 UI + API, forwards /api/todos to todo-store
    ├── todo-store/               # ASP.NET Core 6 in-memory todo store (port 7124)
    ├── build-push.sh             # build + push to reg.k.codersandbox.com
    ├── build-push-dockerhub.sh   # build + push to Docker Hub (alainpham/*)
    ├── deploy.sh                 # deploy using the codersandbox registry images
    ├── deploy-dockerhub.sh       # deploy using the Docker Hub images
    └── otelcoloperator.sh        # install the OpenTelemetry operator stack (Helm)
```

## Demo app (`k8s/`)

| Service | Role | Docs |
|---|---|---|
| `todo-front` | Serves the todo UI and `/api/todos`. Every API call is forwarded over HTTP to `TODO_STORE_URL` (default `http://todo-store`). | [todo-front/README.md](k8s/todo-front/README.md) |
| `todo-store` | Keeps the todos in memory. It runs as a single replica, and data is lost on restart. | [todo-store/README.md](k8s/todo-store/README.md) |

Both services deploy to the `apps` namespace. `todo-front/k8s/traffic.yaml` adds a curl loop that creates and deletes a todo every 5 seconds, so there is always traffic on the chain.

### Prerequisites

- Docker, with `docker login` done if you push to Docker Hub
- `kubectl` pointing at the target cluster
- `helm` and `bash`, for the OpenTelemetry operator install only

### Build, push and deploy

There are two registry variants. Both use the same Deployment names and namespace, so you can switch between them.

| | codersandbox registry | Docker Hub |
|---|---|---|
| Image | `reg.k.codersandbox.com/<project>:latest` | `alainpham/<project>:<tag>` |
| Build and push | `k8s/build-push.sh` | `k8s/build-push-dockerhub.sh [tag]` (default `latest`) |
| Manifests | `*/k8s/deployment.yaml` | `*/k8s/deployment-dockerhub.yaml` |
| Deploy | `k8s/deploy.sh` | `k8s/deploy-dockerhub.sh` |

```bash
cd k8s

# Docker Hub
./build-push-dockerhub.sh
./deploy-dockerhub.sh              # add --no-traffic to skip the traffic generator

# or the codersandbox registry
./build-push.sh
./deploy.sh
```

Notes:

- The deploy scripts create the `apps` namespace, apply the manifests, restart the pods so a re-pushed `:latest` is pulled (the manifests use `imagePullPolicy: Always`), then list the pods.
- The deploy script's pod restart only picks up a new push of the same tag. `build-push-dockerhub.sh v1` pushes `alainpham/*:v1`, but the Docker Hub manifests still reference `:latest`.
- For the cluster to pull from Docker Hub, the `alainpham/*` repos must be public, or the manifests need an `imagePullSecret`.

### Try it

```bash
kubectl -n apps port-forward svc/todo-front 7123:80
# open http://localhost:7123/
```

### Telemetry

`k8s/otelcoloperator.sh` installs the OpenTelemetry operator and collectors (`opentelemetry-kube-stack` chart 0.14.6) in `opentelemetry-operator-system`. They send OTLP to Grafana Cloud. .NET auto-instrumentation is pinned to 1.9.0, the last release that supports .NET 6.

Before running it, set `GCLOUD_RW_API_KEY` in your environment. The script reads the key from there and writes it to a `grafana-cloud-auth` secret, so it is never stored in the file.

### Cleanup

```bash
kubectl delete -f k8s/todo-front/k8s/traffic.yaml
kubectl delete -f k8s/todo-front/k8s/deployment-dockerhub.yaml -f k8s/todo-store/k8s/deployment-dockerhub.yaml
# use deployment.yaml instead if you deployed with deploy.sh
```

The `apps` namespace is created by the script rather than a manifest, so it is not deleted. Remove it with `kubectl delete namespace apps`.

## Alloy config for Windows hosts (`config.alloy`)

The config runs on Windows hosts. It sends everything to a **gateway Alloy** at `FRPR4GRAF-ALLOY.corp.capgemini.com`, which forwards to Grafana Cloud. This config has no Grafana Cloud credentials.

| Signal | Source | Destination (gateway Alloy) |
|---|---|---|
| Alloy self-metrics | `prometheus.exporter.self`, scraped every 15s and filtered to a short keep-list | `:9999/api/v1/metrics/write` (`prometheus.receive_http`) |
| Windows host metrics | `prometheus.exporter.windows` with the cpu, memory, pagefile, logical_disk, net, os, service, system, time and diskdrive collectors. A keep-list restricts the series, and `HarddiskVolume*` volumes are dropped. | OTLP HTTP `:4318`, after resource detection |
| Windows event logs | `loki.source.windowsevent` for the Application and System logs | `:3100/loki/api/v1/push` (`loki.source.api`) |
| Application telemetry | `otelcol.receiver.otlp` on `0.0.0.0:4317` (gRPC) and `0.0.0.0:4318` (HTTP): metrics, logs and traces | OTLP HTTP `:4318` |

The OTLP pipeline works like this:

1. It detects the host with `env` and `system`.
2. It drops noisy resource attributes.
3. It generates host-info metrics for the Grafana host views.
4. It copies `deployment.environment` and `service.version` onto metric datapoints.
5. It batches the data and exports it.

The Windows host metrics use their own resource detection (`env`, `ec2`, `azure`, `gcp`, `system`). The comment in the config says the detector order has to match how `host.id` is resolved for the host's application telemetry.

### Use it

Point Alloy at the file, for example `alloy run config.alloy`, or set it as the config file of the Alloy Windows service. Instrument applications on the host to export OTLP to `localhost:4317` (gRPC) or `localhost:4318` (HTTP).

To change the destination, edit the three gateway URLs near the top of the file.
