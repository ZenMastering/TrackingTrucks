#!/usr/bin/env bash
# Called by deployJenkins.sh before Helm. Writes the JCasC Job DSL config.
set -euo pipefail
CONTEXT="${1:?Kubernetes context required}"
OUTPUT="${2:?Output path required}"
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
kube=(kubectl --context "$CONTEXT")

"${kube[@]}" apply -f "$ROOT/scripts/deploy-code-rbac.yaml"
"${kube[@]}" -n jenkins create configmap deploy-code-scripts \
  --from-file="deploy-code.sh=$ROOT/scripts/deploy-code.sh" \
  --dry-run=client -o yaml | "${kube[@]}" apply -f -


python3 - "$ROOT/jobs/DEPLOY_CODE.Jenkinsfile" "$OUTPUT" <<'PY'
import json
import pathlib
import sys

pipeline = pathlib.Path(sys.argv[1]).read_text()
# Preserve the Jenkinsfile literally inside a Groovy single-quoted string.
quoted = "'" + pipeline.replace("\\", "\\\\").replace("'", "\\'").replace("\r", "\\r").replace("\n", "\\n") + "'"
dsl = """pipelineJob('DEPLOY_CODE') {
  description('Deploy the latest GitHub main branch to production using npm run dev.')
  parameters {
    stringParam('APP_HOST', '', 'Optional exact hostname to allow in Vite, e.g. trucks.example.com.')
  }
  definition {
    cps {
      script(""" + quoted + """)
      sandbox()
    }
  }
}
"""
pathlib.Path(sys.argv[2]).write_text(json.dumps({'jobs': [{'script': dsl}]}))
PY
echo 'DEPLOY_CODE job definition prepared.'
