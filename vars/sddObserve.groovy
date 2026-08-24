#!/usr/bin/env groovy
/**
 * Gate 8 - watch what Argo CD actually did, then tell Jira.
 *
 * Runs as a multibranch job on the GitOps repo's main branch. Every push that
 * touches an overlay lands here, which covers both the direct dev/staging
 * pushes and the merged production pull request. It waits for Argo to report
 * Synced/Healthy, writes the deploy comment and the Deployed Environments
 * field, and reverts if the sync goes Degraded.
 *
 *   @Library('sdd-workflow@main') _
 *   sddObserve()
 *
 * Issue keys are resolved from the Fix Version stamped at gate 7, so this repo
 * needs none of the application's git history.
 */
def call(Map cfg = [:]) {
    def jiraCred = cfg.jiraCredentials ?: 'sdd-jira-token'
    def bbCred = cfg.bitbucketCredentials ?: 'sdd-bitbucket-token'
    def argoCred = cfg.argocdCredentials ?: 'sdd-argocd-token'
    def timeoutMinutes = cfg.healthTimeoutMinutes ?: 15

    pipeline {
        agent { label cfg.agent ?: 'linux' }

        options {
            disableConcurrentBuilds()
            timestamps()
        }

        environment {
            JIRA_URL = "${env.SDD_JIRA_URL}"
            JIRA_PROJECT = "${env.SDD_JIRA_PROJECT}"
            JIRA_EMAIL = "${env.SDD_JIRA_EMAIL ?: ''}"
            JIRA_FIELD_DEPLOYED_ENVS = "${env.SDD_JIRA_FIELD_DEPLOYED_ENVS}"
            ARGOCD_SERVER = "${env.SDD_ARGOCD_SERVER}"
            BITBUCKET_URL = "${env.SDD_BITBUCKET_URL}"
        }

        stages {
            stage('Read what was promoted') {
                steps {
                    script {
                        env.SDD = sddScripts()
                        // scripts/promote.sh writes these trailers. A push
                        // without them is a hand-edited overlay, and there is
                        // nothing to report to Jira.
                        def msg = sh(returnStdout: true, script: 'git log -1 --format=%B')
                        def trailer = { k ->
                            def m = (msg =~ /(?m)^${k}:\s*(.+)$/)
                            m ? m[0][1].trim() : ''
                        }
                        env.SERVICE = trailer('Promote-Service')
                        env.VERSION = trailer('Promote-Version')
                        env.TARGET_ENV = trailer('Promote-Env')
                        env.DIGEST = trailer('Promote-Digest')

                        if (!env.SERVICE) {
                            currentBuild.result = 'NOT_BUILT'
                            currentBuild.displayName = 'not a promotion'
                            echo 'No promotion trailers on this commit - nothing to observe.'
                        } else {
                            currentBuild.displayName = "${env.SERVICE} ${env.VERSION} on ${env.TARGET_ENV}"
                        }
                    }
                }
            }

            stage('Wait for Argo CD') {
                when { expression { env.SERVICE } }
                steps {
                    withCredentials([string(credentialsId: argoCred, variable: 'ARGOCD_TOKEN')]) {
                        timeout(time: timeoutMinutes, unit: 'MINUTES') {
                            sh '''
                                app="${SERVICE}-${TARGET_ENV}"
                                while true; do
                                  state="$(curl -sS -H "Authorization: Bearer ${ARGOCD_TOKEN}" \\
                                    "https://${ARGOCD_SERVER}/api/v1/applications/${app}" \\
                                    | jq -r '"\\(.status.sync.status)/\\(.status.health.status)"')"
                                  echo "argocd: $app -> $state"
                                  case "$state" in
                                    Synced/Healthy) exit 0 ;;
                                    */Degraded)     echo "ERROR: $app is Degraded"; exit 1 ;;
                                  esac
                                  sleep 15
                                done
                            '''
                        }
                    }
                }
            }

            stage('Tell Jira it is live') {
                when { expression { env.SERVICE } }
                steps {
                    withCredentials([string(credentialsId: jiraCred, variable: 'JIRA_TOKEN')]) {
                        sh """
                            transition=""
                            [ "${env.TARGET_ENV}" = "dev" ] && transition="Deployed to dev"
                            ${env.SDD}/jira-deploy.sh \\
                              --service ${env.SERVICE} \\
                              --version ${env.VERSION} \\
                              --env ${env.TARGET_ENV} \\
                              --digest "${env.DIGEST}" \\
                              --url "${env.BUILD_URL}" \\
                              \${transition:+--transition "\$transition"}
                        """
                    }
                }
            }

            stage('Mark the Jira version Released') {
                when {
                    allOf {
                        expression { env.SERVICE }
                        environment name: 'TARGET_ENV', value: 'prod'
                    }
                }
                steps {
                    withCredentials([string(credentialsId: jiraCred, variable: 'JIRA_TOKEN')]) {
                        sh "${env.SDD}/jira-release.sh --service ${env.SERVICE} --version ${env.VERSION} --release"
                    }
                }
            }
        }

        post {
            failure {
                script {
                    if (!env.SERVICE) return
                    // Rollback is a promotion in the other direction. Doing it
                    // automatically is only safe inside the health-check window;
                    // after that, roll forward - see docs/release.md#rollback.
                    withCredentials([
                        string(credentialsId: bbCred, variable: 'BITBUCKET_TOKEN'),
                        string(credentialsId: jiraCred, variable: 'JIRA_TOKEN')
                    ]) {
                        sh """
                            git config user.name  'jenkins-deploy'
                            git config user.email 'jenkins@${env.SDD_MAIL_DOMAIN ?: 'localhost'}'
                            git revert --no-edit HEAD
                            git push origin HEAD:main
                            ${env.SDD}/jira-deploy.sh \\
                              --service ${env.SERVICE} --version ${env.VERSION} \\
                              --env ${env.TARGET_ENV} --rollback --url "${env.BUILD_URL}"
                        """
                    }
                }
            }
            cleanup { cleanWs() }
        }
    }
}
