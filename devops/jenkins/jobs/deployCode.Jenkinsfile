// Seeded by deployJenkins.sh; helpers are mounted from a ConfigMap.
properties([
    disableConcurrentBuilds(),
    buildDiscarder(logRotator(numToKeepStr: '15')),
    parameters([string(name: 'APP_HOST', defaultValue: '', description: 'Optional exact hostname to allow in Vite.')])
])

timeout(time: 20, unit: 'MINUTES') {
    podTemplate(cloud: 'kubernetes', namespace: 'jenkins', yaml: """
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: deploy-code
  securityContext:
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
  containers:
    - name: deploy
      image: node:24-bookworm
      command: ["sleep"]
      args: ["infinity"]
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: "1"
          memory: 512Mi
      volumeMounts:
        - name: scripts
          mountPath: /opt/deploy-code
          readOnly: true
  volumes:
    - name: scripts
      configMap:
        name: deploy-code-scripts
""") {
        node(POD_LABEL) {
            container('deploy') {
                stage('Deploy main to production') {
                    sh('bash /opt/deploy-code/deploy-code.sh')
                }
            }
        }
    }
}
