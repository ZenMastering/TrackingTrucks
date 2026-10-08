properties([
    disableConcurrentBuilds(),
    buildDiscarder(logRotator(numToKeepStr: '15')),
    parameters([
        string(
            name: 'REPO_URL',
            defaultValue: 'git@github.com:ZenMastering/TrackingTrucks.git',
            description: 'Git repository SSH URL'
        ),
        string(
            name: 'BRANCH',
            defaultValue: 'main',
            description: 'Branch to check out and deploy to production'
        ),
        string(
            name: 'GIT_CREDENTIALS_ID',
            defaultValue: 'github-ssh',
            description: 'Jenkins SSH credential ID'
        )
    ])
])

timeout(time: 30, unit: 'MINUTES') {
    podTemplate(
        cloud: 'kubernetes',
        namespace: 'production',
        podRetention: onFailure(),
        workspaceVolume: persistentVolumeClaimWorkspaceVolume(
            claimName: 'trackingtrucks-releases',
            readOnly: false
        ),
        yaml: '''
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: deploy-code
  securityContext:
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
  containers:
    - name: jnlp
      image: jenkins/inbound-agent:jdk21
      imagePullPolicy: Always
      workingDir: /home/jenkins/agent
    - name: build
      image: node:24-bookworm
      workingDir: /home/jenkins/agent
      command: ["sleep"]
      args: ["infinity"]
      resources:
        requests:
          cpu: 100m
          memory: 256Mi
        limits:
          cpu: "2"
          memory: 2Gi
      volumeMounts:
        - name: scripts
          mountPath: /opt/deploy-code
          readOnly: true
  volumes:
    - name: scripts
      configMap:
        name: deploy-code-scripts
'''
    ) {
        node(POD_LABEL) {
            container('build') {
                env.RELEASE_ID = env.BUILD_TAG + '-' + sh(
                    script: 'date -u +%Y%m%dT%H%M%S',
                    returnStdout: true
                ).trim()

                withEnv(['BRANCH=' + (params.BRANCH ?: 'main').trim(), 'REPO_URL=' + params.REPO_URL]) {
                    ws('/home/jenkins/agent/releases/' + env.RELEASE_ID) {
                        stage('Checkout repository') {
                            sh('git check-ref-format "refs/heads/$BRANCH"')

                            def revision = checkout([
                                $class: 'GitSCM',
                                branches: [[
                                    name: 'refs/remotes/origin/' + env.BRANCH
                                ]],
                                userRemoteConfigs: [[
                                    url: params.REPO_URL,
                                    credentialsId: params.GIT_CREDENTIALS_ID,
                                    refspec: '+refs/heads/' + env.BRANCH +
                                             ':refs/remotes/origin/' + env.BRANCH
                                ]],
                                extensions: [[
                                    $class: 'CloneOption',
                                    shallow: false,
                                    noTags: true,
                                    honorRefspec: true
                                ]]
                            ])

                            env.DEPLOY_COMMIT = revision.GIT_COMMIT

                            def config = readYaml(
                                file: 'devops/jenkins/environments.yaml'
                            )
                            def production = config?.environments?.production

                            if (production?.namespace != 'production') {
                                error(
                                    'environments.yaml must define ' +
                                    'production.namespace as production.'
                                )
                            }

                            def hostname = production?.hostname

                            if (!(hostname instanceof String)) {
                                error('production.hostname must be a string.')
                            }

                            hostname = hostname.trim()

                            if (hostname.length() > 253 ||
                                !(hostname ==~
                                    /[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+/)) {
                                error(
                                    'production.hostname must be a DNS hostname ' +
                                    'without a scheme, port, or path.'
                                )
                            }

                            env.APP_HOST = hostname
                            env.DEPLOY_NAMESPACE = production.namespace

                            currentBuild.description =
                                'production: ' + env.BRANCH + ' @ ' +
                                env.DEPLOY_COMMIT.take(12)

                            echo('Branch: ' + env.BRANCH)
                            echo('Commit: ' + env.DEPLOY_COMMIT)
                            echo('Application URL: https://' + env.APP_HOST)
                        }

                        stage('Clean workspace') {
                            sh('bash /opt/deploy-code/deploy-code.sh stop')
                        }

                        stage('Build code') {
                            sh('bash /opt/deploy-code/compile-application.sh')
                        }

                        stage('Cut release') {
                            sh('bash /opt/deploy-code/deploy-code.sh release')
                            echo('Application URL: https://' + env.APP_HOST)
                        }
                    }
                }
            }
        }
    }
}