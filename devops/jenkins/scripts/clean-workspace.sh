#!/usr/bin/env bash
set -euo pipefail

namespace=production
application=trackingtrucks

case "$(uname -m)" in
  x86_64) arch=amd64 ;;
  aarch64|arm64) arch=arm64 ;;
  *)
    echo 'Unsupported architecture' >&2
    exit 1
    ;;
esac

version=v1.36.4
bin_dir="$(mktemp -d)"
trap 'rm -rf -- "$bin_dir"' EXIT

base_url="https://dl.k8s.io/release/$version/bin/linux/$arch"

curl -fsSL --retry 3 "$base_url/kubectl" \
  -o "$bin_dir/kubectl"

curl -fsSL --retry 3 "$base_url/kubectl.sha256" \
  -o "$bin_dir/kubectl.sha256"

printf '%s  %s\n' \
  "$(cat "$bin_dir/kubectl.sha256")" \
  "$bin_dir/kubectl" |
  sha256sum --check

chmod +x "$bin_dir/kubectl"

kube() {
  "$bin_dir/kubectl" \
    --namespace="$namespace" \
    --request-timeout=15s \
    "$@"
}

deployment="$(kube get deployment "$application" --ignore-not-found -o name)"

if [[ -n "$deployment" ]]; then
  echo "Stopping $namespace/$application..."

  kube patch deployment "$application" \
    --type=merge \
    -p '{"spec":{"replicas":0}}'
fi

deadline=$((SECONDS + 180))

while true; do
  pods="$(kube get pods -l "app=$application" -o name)"

  if [[ -z "$pods" ]]; then
    echo 'Cleanup complete. No application pods remain.'
    break
  fi

  if (( SECONDS >= deadline )); then
    echo 'Timed out waiting for application pods to terminate.' >&2
    printf '%s\n' "$pods" >&2
    exit 1
  fi

  sleep 3
done
