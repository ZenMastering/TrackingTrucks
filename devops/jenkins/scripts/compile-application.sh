#!/usr/bin/env bash
set -euo pipefail
: "${DEPLOY_COMMIT:?Checkout must run first}"

export ELECTRON_SKIP_BINARY_DOWNLOAD=1
export npm_config_cache=/tmp/npm-cache
npm ci --include=dev
npm run build
test -s dist/index.html

# The release step accepts only the commit that compiled successfully.
printf '%s\n' "$DEPLOY_COMMIT" > .deploy-code-built
node <<'JS'
const fs = require('node:fs');
fs.writeFileSync('.deploy-code-release.json', JSON.stringify({
  commit: process.env.DEPLOY_COMMIT,
  branch: process.env.BRANCH,
  repository: process.env.REPO_URL,
  release: process.env.RELEASE_ID,
  buildUrl: process.env.BUILD_URL,
  compiledAt: new Date().toISOString()
}, null, 2) + '\n');
JS
