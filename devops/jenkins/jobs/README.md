# DEPLOY_CODE

Source: jobs/deployCode.Jenkinsfile. Jenkins display name: DEPLOY_CODE.

## Setup

1. In Jenkins, add an "SSH Username with private key" credential with ID
   github-ssh (username git for GitHub). Register the public key with GitHub.
   The key is used by Jenkins checkout; it is not placed in application pods.
2. Configure Jenkins Git Host Key Verification for GitHub. The included Helm
   values trust GitHub's published Ed25519 key.
3. From the repository root, run:
   bash devops/jenkins/deployJenkins.sh

The installer seeds/updates the job, publishes both helper scripts, and provisions
the production service accounts, permissions, and trackingtrucks-releases PVC.
It does not trigger DEPLOY_CODE. The PVC uses the existing local-path StorageClass.

## Build with Parameters

- REPO_URL: defaults to git@github.com:ZenMastering/TrackingTrucks.git
- BRANCH: defaults to main; accepts branches such as feature/my-change
- GIT_CREDENTIALS_ID: defaults to github-ssh
- APP_HOST: optional exact Vite hostname; leave empty for localhost/port-forward

The parameters are seeded before the first run, not only after it.

## Stages

1. Checkout repository: the Jenkins Git plugin clones the selected branch with
   the chosen Jenkins credential and records the exact commit.
2. Compile application: a Node 24 Jenkins agent pod in production runs npm ci
   and npm run build. No application tests run. A failed build stops here.
3. Cut release: updates the trackingtrucks Deployment and Service in production
   to mount that build's directory, then waits for readiness. This does not create
   a Git tag or GitHub Release. The current pod stays until its replacement is ready.

The application continues to run npm run dev on 0.0.0.0:5173 as requested.
The compile stage creates dist and validates compilation; the dev server still
serves the matching source. To serve only dist instead, change the runtime command
in scripts/deploy-code.sh from dev to preview.

## Storage and access

Each build uses a unique releases/<release-id> directory on a shared 20Gi PVC.
Source, dependencies, and compiled output remain after the Jenkins agent exits.
Only that release directory is mounted in the application. Application pods do
not clone the repo or get a GitHub credential; restarts reuse the same commit.
No registry or Docker image build is required.

ReadWriteOnce/local-path keeps the builder and application on the same storage
node. This is intended for the current home K3s setup. Retained release directories
consume disk; Jenkins build-log retention does not remove them. Keep directories
needed by the live Deployment and rollback revisions when cleaning old releases.

Access locally, or forward this port through VS Code:
  kubectl -n production port-forward svc/trackingtrucks 5173:80

Open http://localhost:5173. No new ingress or Tailscale route is created.

Changes were checked for script syntax and job generation only. Jenkins deployment
and application builds were not run as part of this edit.
