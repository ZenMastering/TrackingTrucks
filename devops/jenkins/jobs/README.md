# DEPLOY_CODE

Run the existing installer from the repository root:

```bash
bash devops/jenkins/deployJenkins.sh
```

It seeds/updates DEPLOY_CODE from jobs/DEPLOY_CODE.Jenkinsfile, publishes scripts
in a ConfigMap, and provisions a deployment service account with permissions only
in production. Seeding creates the job; it does not run it.

The public repository is cloned over HTTPS; no GitHub credentials are needed.

In Jenkins, open DEPLOY_CODE -> Build with Parameters -> Build.
APP_HOST can be left empty for localhost/port-forward access.
Each run rolls out one trackingtrucks pod in production. The init container clones
the current main branch and runs npm ci; the app runs npm run dev on 0.0.0.0:5173.
The exact cloned commit is printed in the init container logs. Recreated pods also
fetch the latest main. There is no image build, registry push, or test stage.
Node 24 follows the project's .nvmrc major version. Electron's binary download is
skipped because this deployment runs the Vite web app.

The job waits for readiness before succeeding. View the pod in Rancher's production
namespace. To access it locally (or via VS Code's forwarded port):

```bash
kubectl -n production port-forward svc/trackingtrucks 5173:80
```

Open http://localhost:5173. If you add an ingress or Tailscale route, supply its exact
hostname in APP_HOST. This change does not create an external route.

The runtime downloads a checksummed kubectl v1.36.4 binary into its temporary agent;
GitHub, the container registry, dl.k8s.io, and npm must be reachable.
Source and node_modules use an emptyDir volume, not persistent application storage.
Deployment scripts have not been executed or tested against the cluster.
