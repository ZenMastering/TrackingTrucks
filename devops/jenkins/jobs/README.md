# DEPLOY_CODE

Run bash devops/jenkins/deployJenkins.sh from the repository root to seed the job and refresh its mounted scripts.

## Parameters and configuration

- REPO_URL: repository SSH URL.
- BRANCH: branch to release, defaulting to main.
- GIT_CREDENTIALS_ID: Jenkins SSH credential ID, defaulting to github-ssh.

Store the private key in Jenkins Credentials and grant its public key repository access.
The selected branch must contain devops/jenkins/environments.yaml.
The pipeline reads production.namespace and production.hostname from that file.
This job targets production; testing and staging entries are reserved for separate jobs.
No APP_HOST build parameter is needed.

## Stages

1. Checkout repository: clone the selected branch, validate production settings, and record the commit.
2. Clean workspace: call the mounted deploy-code.sh stop operation. Set trackingtrucks replicas to zero and wait up to three minutes for its application pods to disappear. A missing Deployment is accepted for the first release.
3. Build code: install dependencies with npm ci and run npm run build.
4. Cut release: call the same mounted deploy-code.sh release operation. Validate the compiled commit, apply the Deployment with one replica, and wait for readiness.

The app is offline between cleanup and a successful release. Build failure leaves it stopped.
Cleanup preserves the Service, PVC, release files, namespace and Jenkins agent.
The deployment script explicitly authenticates to the in-cluster Kubernetes API using the build pod's deploy-code service account. No Rancher admin credentials are required.

## Storage and access

Each build gets a separate releases/<release-id> directory on trackingtrucks-releases.
The application mounts that directory and runs npm run dev on port 5173.
The production trackingtrucks Service exposes port 80.
Compilation validates dist; the runtime continues serving the selected source with Vite.
The YAML hostname is passed to Vite's allowed-host environment variable.
Existing Tailscale forwarding is configured separately and continues using the Service.

Release directories are retained on the PVC; Jenkins build-log retention does not remove them.
Keep directories used by current or rollback releases.
The local-path PVC places the build and application pods on the storage node.
