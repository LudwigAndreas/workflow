#!/usr/bin/env groovy
/**
 * Gate 10 (and the write half of gate 8) - promote an image between Argo CD
 * overlays. Runs in a GitOps repo as a *parameterised* job, not a multibranch
 * one, because it is always triggered by something else:
 *
 *   dev      upstream sddRelease finished          -> writes the dev overlay
 *   staging  Jira webhook when gate 9 passes       -> copies dev -> staging
 *   prod     a human runs it (Build with Parameters) -> opens a Bitbucket PR
 *
 * Promotion copies a digest; it never rebuilds. dev and staging land straight
 * on main. prod stops at an open pull request, because merging that PR *is*
 * gate 10 - and merging it is what fires sddObserve. Nothing here waits on a
 * sync a human has not approved yet.
 *
 *   @Library('sdd-workflow@main') _
 *   sddPromote(bitbucketProject: 'PLAT', bitbucketRepo: 'gitops-backend')
 */
def call(Map cfg = [:]) {
    def bbProject = cfg.bitbucketProject ?: error('sddPromote: "bitbucketProject" is required')
    def bbRepo = cfg.bitbucketRepo ?: error('sddPromote: "bitbucketRepo" is required')
    def bbCred = cfg.bitbucketCredentials ?: 'sdd-bitbucket-token'

    pipeline {
        agent { label cfg.agent ?: 'linux' }

        parameters {
            string(name: 'SERVICE', defaultValue: '', description: 'Service to promote')
            string(name: 'VERSION', defaultValue: '', description: 'Version to promote')
            string(name: 'DIGEST', defaultValue: '', description: 'Image digest (dev only; staging/prod copy it)')
            choice(name: 'TARGET_ENV', choices: ['dev', 'staging', 'prod'], description: 'Where to promote to')
            string(name: 'SOURCE_ENV', defaultValue: '', description: 'Overlay to copy from; blank for a fresh build')
            string(name: 'KEYS', defaultValue: '', description: 'Jira keys (optional; resolved from Fix Version otherwise)')
        }

        options {
            disableConcurrentBuilds()
            timestamps()
        }

        environment {
            BITBUCKET_URL = "${env.SDD_BITBUCKET_URL}"
            BITBUCKET_PROJECT = "${bbProject}"
            BITBUCKET_REPO = "${bbRepo}"
        }

        stages {
            stage('Checkout') {
                steps {
                    checkout scm
                    script { env.SDD = sddScripts() }
                }
            }

            stage('Validate') {
                steps {
                    script {
                        if (!params.SERVICE || !params.VERSION) {
                            error 'SERVICE and VERSION are required'
                        }
                        if (params.TARGET_ENV != 'dev' && !params.SOURCE_ENV) {
                            // Promoting to staging or prod must copy a digest
                            // that was already verified somewhere, never a
                            // freshly supplied one.
                            error "promoting to ${params.TARGET_ENV} requires SOURCE_ENV"
                        }
                        currentBuild.displayName = "${params.SERVICE} ${params.VERSION} -> ${params.TARGET_ENV}"
                    }
                }
            }

            stage('Write the overlay') {
                steps {
                    withCredentials([string(credentialsId: bbCred, variable: 'BITBUCKET_TOKEN')]) {
                        script {
                            def args = "--service ${params.SERVICE} --to ${params.TARGET_ENV}"
                            args += params.SOURCE_ENV ? " --from ${params.SOURCE_ENV}"
                                                      : " --digest ${params.DIGEST} --version ${params.VERSION}"
                            // prod opens a PR and stops; dev/staging land directly
                            def mode = params.TARGET_ENV == 'prod' ? '--pr' : '--push'
                            sh """
                                git config user.name  'jenkins-deploy'
                                git config user.email 'jenkins@${env.SDD_MAIL_DOMAIN ?: 'localhost'}'
                                git remote set-url --push origin \\
                                  \$(git remote get-url origin)
                                ${env.SDD}/promote.sh ${args} ${mode}
                            """
                        }
                    }
                }
            }
        }

        post {
            success {
                script {
                    if (params.TARGET_ENV == 'prod') {
                        echo 'Pull request opened. Gate 10 is a human merging it; sddObserve takes over from there.'
                    } else {
                        echo "Pushed. sddObserve will pick up the ${params.TARGET_ENV} sync."
                    }
                }
            }
            cleanup { cleanWs() }
        }
    }
}
