#!/usr/bin/env bash
# Runs inside the Jenkins agent. No image build or application tests.
set -euo pipefail
APP_HOST="${APP_HOST:-}"
export APP_HOST
case "$(uname -m)" in
  x86_64) arch=amd64 ;;
  aarch64|arm64) arch=arm64 ;;
  *) echo "Unsupported architecture" >&2; exit 1 ;;
esac
version=v1.36.4
mkdir -p /tmp/deploy-code-bin
cd /tmp/deploy-code-bin
curl -fsSL --retry 3 "https://dl.k8s.io/release/$version/bin/linux/$arch/kubectl" -o kubectl
curl -fsSL --retry 3 "https://dl.k8s.io/release/$version/bin/linux/$arch/kubectl.sha256" -o kubectl.sha256
printf '%s  kubectl\n' "$(cat kubectl.sha256)" | sha256sum --check
chmod +x kubectl
export PATH="/tmp/deploy-code-bin:$PATH"
export DEPLOY_REVISION="$BUILD_TAG-$(date +%s)"

# JSON is accepted by kubectl and keeps parameter values safely quoted.
node <<'JS' | kubectl -n production apply -f -
const labels = {app: 'trackingtrucks'};
const git = 'https://github.com/ZenMastering/TrackingTrucks.git';
const clone = [
  'set -eu',
  'git clone --depth 1 --single-branch --branch main "$GIT_REPOSITORY" /app',
  'cd /app',
  'git rev-parse HEAD',
  'npm ci --include=dev'
].join('\n');
const deployment = {
  apiVersion: 'apps/v1', kind: 'Deployment',
  metadata: {name: 'trackingtrucks', namespace: 'production'},
  spec: {
    replicas: 1,
    selector: {matchLabels: labels},
    strategy: {type: 'RollingUpdate', rollingUpdate: {maxUnavailable: 0, maxSurge: 1}},
    template: {
      metadata: {labels, annotations: {'trackingtrucks/deploy-revision': process.env.DEPLOY_REVISION}},
      spec: {
        automountServiceAccountToken: false,
        securityContext: {runAsUser: 1000, runAsGroup: 1000, fsGroup: 1000},
        initContainers: [{
          name: 'clone', image: 'node:24-bookworm',
          command: ['bash', '-c', clone],
          env: [{name: 'GIT_REPOSITORY', value: git},
                {name: 'ELECTRON_SKIP_BINARY_DOWNLOAD', value: '1'},
                {name: 'npm_config_cache', value: '/tmp/npm-cache'}],
          resources: {requests: {cpu: '100m', memory: '256Mi'}, limits: {cpu: '2', memory: '2Gi'}},
          volumeMounts: [{name: 'source', mountPath: '/app'}]
        }],
        containers: [{
          name: 'app', image: 'node:24-bookworm', workingDir: '/app',
          command: ['npm', 'run', 'dev', '--', '--host', '0.0.0.0', '--port', '5173', '--strictPort'],
          env: [{name: '__VITE_ADDITIONAL_SERVER_ALLOWED_HOSTS', value: process.env.APP_HOST || ''}],
          ports: [{name: 'http', containerPort: 5173}],
          readinessProbe: {httpGet: {path: '/', port: 'http'}, periodSeconds: 5},
          resources: {requests: {cpu: '100m', memory: '256Mi'}, limits: {cpu: '1', memory: '1Gi'}},
          volumeMounts: [{name: 'source', mountPath: '/app'}]
        }],
        volumes: [{name: 'source', emptyDir: {}}]
      }
    }
  }
};
const service = {
  apiVersion: 'v1', kind: 'Service',
  metadata: {name: 'trackingtrucks', namespace: 'production'},
  spec: {type: 'ClusterIP', selector: labels, ports: [{name: 'http', port: 80, targetPort: 'http'}]}
};
process.stdout.write(JSON.stringify({apiVersion: 'v1', kind: 'List', items: [deployment, service]}));
JS

kubectl -n production rollout status deployment/trackingtrucks --timeout=10m
kubectl -n production get pods -l app=trackingtrucks
echo 'Ready: service trackingtrucks.production.svc.cluster.local:80'
echo 'From your server: kubectl -n production port-forward svc/trackingtrucks 5173:80'
