#!/usr/bin/env bash
# Renders everything Argo CD would deploy and validates it offline.
# Runs in CI on every PR, and locally: scripts/validate.sh
set -euo pipefail
cd "$(dirname "$0")/.."

NATS_CHART_VERSION=$(grep -A2 'chart: nats' argocd/appset-environments.yaml | awk '/targetRevision/ {print $2}')
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT
fail=0

echo "== Image tag policy (immutable sha-<commit> tags only)"
for f in envs/*/services/*.yaml; do
  tag=$(awk '/^  tag:/ {print $2}' "$f")
  if [[ ! $tag =~ ^sha-[0-9a-f]{7,40}$ ]]; then
    echo "  FAIL $f: tag '$tag' is not sha-<commit>"; fail=1
  fi
done
[[ $fail -eq 0 ]] && echo "  ok"

echo "== Every service file has matching base values"
for f in envs/*/services/*.yaml; do
  svc=$(basename "$f" .yaml)
  [[ -f values/$svc.yaml ]] || { echo "  FAIL $f: values/$svc.yaml missing"; fail=1; }
done
[[ $fail -eq 0 ]] && echo "  ok"

echo "== Render"
for envdir in envs/*/; do
  env=$(basename "$envdir")
  for f in "$envdir"services/*.yaml; do
    svc=$(basename "$f" .yaml)
    helm lint --quiet charts/shoplite-service -f "values/$svc.yaml" -f "$f" >/dev/null
    helm template "$svc" charts/shoplite-service -n "shoplite-$env" \
      -f "values/$svc.yaml" -f "$f" > "$OUT/$env-$svc.yaml"
  done
  helm template data charts/shoplite-data -n "shoplite-$env" -f "$envdir/data.yaml" > "$OUT/$env-data.yaml"
  helm template edge charts/shoplite-edge -n "shoplite-$env" -f "$envdir/edge.yaml" > "$OUT/$env-edge.yaml"
  echo "  $env: $(ls "$envdir"services | wc -l) services + data + edge"
done

helm template nats nats --repo https://nats-io.github.io/k8s/helm/charts/ \
  --version "$NATS_CHART_VERSION" -f envs/nats-values.yaml > "$OUT/nats.yaml"
cp argocd/*.yaml "$OUT/"
for f in platform/*/*.yaml; do cp "$f" "$OUT/platform-$(basename "$(dirname "$f")")-$(basename "$f")"; done
echo "  nats chart $NATS_CHART_VERSION + argocd/ + platform/ manifests"

echo "== Schema validation (kubeconform, incl. Argo CD and CloudNativePG CRDs)"
kubeconform -strict -summary -kubernetes-version 1.35.0 \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  "$OUT"/*.yaml || fail=1

exit $fail
