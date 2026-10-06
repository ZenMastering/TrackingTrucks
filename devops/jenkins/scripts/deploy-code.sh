#!/usr/bin/env bash
set -euo pipefail

operation="${1:-release}"
case "$operation" in
  stop|release) ;;
  *) echo 'Usage: deploy-code.sh [stop|release]' >&2; exit 2 ;;
esac

: "${DEPLOY_NAMESPACE:?Pipeline must select a deployment namespace}"
[[ "$DEPLOY_NAMESPACE" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]] || {
  echo 'Invalid deployment namespace' >&2; exit 1;
}
export DEPLOY_NAMESPACE
: "${DEPLOY_COMMIT:?}"
: "${RELEASE_ID:?}"
[[ "$DEPLOY_COMMIT" =~ ^[0-9a-f]{40,64}$ ]] || { echo 'Invalid commit' >&2; exit 1; }
[[ "$RELEASE_ID" =~ ^[A-Za-z0-9_.-]+$ ]] || { echo 'Invalid release ID' >&2; exit 1; }
[[ "$PWD" == "/home/jenkins/agent/releases/$RELEASE_ID" ]] || {
  echo 'Release must run from its persistent workspace.' >&2; exit 1;
}
if [[ "$operation" == release ]]; then
[[ "$(cat .deploy-code-built)" == "$DEPLOY_COMMIT" ]] || {
  echo 'This commit has not compiled successfully.' >&2; exit 1;
}
fi

case "$(uname -m)" in
  x86_64) arch=amd64 ;;
  aarch64|arm64) arch=arm64 ;;
  *) echo 'Unsupported architecture' >&2; exit 1 ;;
esac
version=v1.36.4
bin_dir="$(mktemp -d)"
trap 'rm -rf -- "$bin_dir"' EXIT
curl -fsSL --retry 3 "https://dl.k8s.io/release/$version/bin/linux/$arch/kubectl" -o "$bin_dir/kubectl"
curl -fsSL --retry 3 "https://dl.k8s.io/release/$version/bin/linux/$arch/kubectl.sha256" -o "$bin_dir/kubectl.sha256"
printf '%s  %s\n' "$(cat "$bin_dir/kubectl.sha256")" "$bin_dir/kubectl" | sha256sum --check
chmod +x "$bin_dir/kubectl"
export PATH="$bin_dir:$PATH"

service_account=/var/run/secrets/kubernetes.io/serviceaccount
[[ -r "$service_account/token" && -r "$service_account/ca.crt" ]] || {
  echo 'Run this script in the Jenkins build pod with serviceAccountName: deploy-code.' >&2
  exit 1
}
export KUBECONFIG="$bin_dir/kubeconfig"
cat > "$KUBECONFIG" <<'YAML'
apiVersion: v1
kind: Config
clusters:
  - name: cluster
    cluster:
      server: https://kubernetes.default.svc
      certificate-authority: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
users:
  - name: deploy-code
    user:
      tokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
contexts:
  - name: deploy-code
    context:
      cluster: cluster
      user: deploy-code
current-context: deploy-code
YAML

kube() {
  kubectl --namespace="$DEPLOY_NAMESPACE" --request-timeout=15s "$@"
}

if [[ "$operation" == stop ]]; then
  deployment="$(kube get deployment trackingtrucks --ignore-not-found -o name)"
  if [[ -n "$deployment" ]]; then
    echo "Stopping $DEPLOY_NAMESPACE/trackingtrucks before building..."
    kube patch deployment trackingtrucks --type=merge -p '{"spec":{"replicas":0}}'
  fi

  deadline=$((SECONDS + 180))
  while true; do
    pods="$(kube get pods -l app=trackingtrucks -o name)"
    [[ -n "$pods" ]] || break
    if (( SECONDS >= deadline )); then
      echo 'Timed out waiting for application pods to terminate.' >&2
      printf '%s\n' "$pods" >&2
      exit 1
    fi
    sleep 3
  done

  echo 'Application pods stopped. Workspace, storage and Service preserved.'
  exit 0
fi

export APP_HOST="${APP_HOST:-}"

# JSON safely quotes all user-supplied values.
node <<'JS' | kube apply -f -
const labels = {app: 'trackingtrucks'};
const deployment = {
  apiVersion: 'apps/v1', kind: 'Deployment',
  metadata: {name: 'trackingtrucks', namespace: process.env.DEPLOY_NAMESPACE},
  spec: {
    replicas: 1,
    revisionHistoryLimit: 5,
    selector: {matchLabels: labels},
    strategy: {type: 'RollingUpdate', rollingUpdate: {maxUnavailable: 0, maxSurge: 1}},
    template: {
      metadata: {
        labels,
        annotations: {
          'trackingtrucks/release': process.env.RELEASE_ID,
          'trackingtrucks/commit': process.env.DEPLOY_COMMIT,
          'trackingtrucks/branch': process.env.BRANCH
        }
      },
      spec: {
        automountServiceAccountToken: false,
        securityContext: {runAsUser: 1000, runAsGroup: 1000, fsGroup: 1000},
        containers: [{
          name: 'app',
          image: 'node:24-bookworm',
          workingDir: '/app',
          command: ['npm', 'run', 'dev', '--', '--host', '0.0.0.0', '--port', '5173', '--strictPort'],
          env: [{name: '__VITE_ADDITIONAL_SERVER_ALLOWED_HOSTS', value: process.env.APP_HOST}],
          ports: [{name: 'http', containerPort: 5173}],
          readinessProbe: {httpGet: {path: '/', port: 'http'}, periodSeconds: 5},
          resources: {requests: {cpu: '100m', memory: '256Mi'}, limits: {cpu: '1', memory: '1Gi'}},
          volumeMounts: [{
            name: 'releases',
            mountPath: '/app',
            subPath: 'releases/' + process.env.RELEASE_ID
          }]
        }],
        volumes: [{
          name: 'releases',
          persistentVolumeClaim: {claimName: 'trackingtrucks-releases'}
        }]
      }
    }
  }
};
const service = {
  apiVersion: 'v1', kind: 'Service',
  metadata: {name: 'trackingtrucks', namespace: process.env.DEPLOY_NAMESPACE},
  spec: {type: 'ClusterIP', selector: labels, ports: [{name: 'http', port: 80, targetPort: 'http'}]}
};
process.stdout.write(JSON.stringify({apiVersion: 'v1', kind: 'List', items: [deployment, service]}));
JS

kube rollout status deployment/trackingtrucks --timeout=10m
echo "Released $BRANCH at $DEPLOY_COMMIT as $RELEASE_ID."
echo "Access: https://$APP_HOST"
