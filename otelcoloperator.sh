#!/usr/bin/env bash
# Uses bash-only ${var//pattern/repl}; run with bash, not dash/sh.
# .NET auto-instrumentation pinned to 1.9.0: the last release supporting .NET 6 (dropped in 1.10.0).
GRAFANA_CLOUD_INSTANCE_ID="1293994" \
GRAFANA_CLOUD_API_KEY="${GCLOUD_RW_API_KEY}" \
GRAFANA_CLOUD_OTLP_ENDPOINT="https://otlp-gateway-prod-eu-west-2.grafana.net/otlp" \
K8S_CURRENT_CONTEXT="$(kubectl config current-context)" \
K8S_CLUSTER_NAME="codersandbox" \
OTEL_OPERATOR_CERT_MANAGER_ENABLED="false" \
DEPLOYMENT_ENVIRONMENT_NAME="production" \
DOTNET_AUTO_INSTRUMENTATION_IMAGE="ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-dotnet:1.9.0" \
GRAFANA_CLOUD_BASIC_AUTH_HEADER="Basic $(printf '%s:%s' "$GRAFANA_CLOUD_INSTANCE_ID" "$GRAFANA_CLOUD_API_KEY" | base64 -w0)" && \
kubectl create namespace opentelemetry-operator-system \
  || echo "WARNING: Could not create namespace 'opentelemetry-operator-system' (may already exist or insufficient permissions). Continuing..." && \
kubectl create secret generic grafana-cloud-auth \
  --namespace opentelemetry-operator-system \
  --from-literal=GRAFANA_CLOUD_INSTANCE_ID="$GRAFANA_CLOUD_INSTANCE_ID" \
  --from-literal=GRAFANA_CLOUD_OTLP_ENDPOINT="$GRAFANA_CLOUD_OTLP_ENDPOINT" \
  --from-literal=GRAFANA_CLOUD_API_KEY="$GRAFANA_CLOUD_API_KEY" \
  --from-literal=GRAFANA_CLOUD_BASIC_AUTH_HEADER="$GRAFANA_CLOUD_BASIC_AUTH_HEADER" \
  || echo "WARNING: Could not create secret 'grafana-cloud-auth' (may already exist). Continuing..." && \
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts && \
helm repo update && \
helm upgrade opentelemetry-stack \
  open-telemetry/opentelemetry-kube-stack \
  --version 0.14.6 \
  --install \
  --namespace opentelemetry-operator-system \
  --set opentelemetry-operator.admissionWebhooks.certManager.enabled=$OTEL_OPERATOR_CERT_MANAGER_ENABLED \
  --set-string clusterName="$K8S_CLUSTER_NAME" \
  --set-string 'instrumentation.resource.resourceAttributes.deployment\.environment\.name'="$DEPLOYMENT_ENVIRONMENT_NAME" \
  --set-string instrumentation.dotnet.image="$DOTNET_AUTO_INSTRUMENTATION_IMAGE" \
  -f https://raw.githubusercontent.com/grafana/opentelemetry-onboarding/refs/heads/chart-0.14.6+collector-0.148.0/kubernetes/otel-kube-stack-helm-chart/values.yaml