#!/usr/bin/env groovy
/**
 * Gate 7 - release on merge. Runs in an application repo on every push to main.
 *
 *   @Library('sdd-workflow@main') _
 *   sddRelease(
 *       service: 'backend',
 *       registry: 'registry.acme.com/platform',
 *       gitopsJob: 'gitops/backend-promote',
 *       build: { v -> sh "make docker-build VERSION=${v}" }   // optional
 *   )
 *
 * Computes the next version from conventional commits, builds and pushes an
 * image by digest, tags, stamps Jira Fix Versions, and asks the GitOps job to
 * roll dev. Nobody types a version number. See docs/release.md.
 *
 * Jenkins credentials expected (IDs overridable via cfg):
 *   sdd-jira-token       secret text
 *   sdd-bitbucket-token  secret text, HTTP access token with repo write
 *   sdd-registry         username/password for the image registry
 */
def call(Map cfg = [:]) {
    def service = cfg.service ?: error('sddRelease: "service" is required')
    def registry = cfg.registry ?: env.SDD_REGISTRY ?: error('sddRelease: "registry" is required')
    def gitopsJob = cfg.gitopsJob ?: error('sddRelease: "gitopsJob" is required')
    def jiraCred = cfg.jiraCredentials ?: 'sdd-jira-token'
    def bbCred = cfg.bitbucketCredentials ?: 'sdd-bitbucket-token'
    def regCred = cfg.registryCredentials ?: 'sdd-registry'

    pipeline {
        agent { label cfg.agent ?: 'docker' }

        options {
            // Releases must not overlap: two concurrent runs would compute the
            // same next version and race for the same tag.
            disableConcurrentBuilds()
            timestamps()
            buildDiscarder(logRotator(numToKeepStr: '50'))
        }

        environment {
            SERVICE = "${service}"
            REGISTRY = "${registry}"
            JIRA_URL = "${env.SDD_JIRA_URL}"
            JIRA_PROJECT = "${env.SDD_JIRA_PROJECT}"
            JIRA_EMAIL = "${env.SDD_JIRA_EMAIL ?: ''}"
            // bb_build_status goes through bb_rest, which requires this.
            // Without it the post block silently posts nothing.
            BITBUCKET_URL = "${env.SDD_BITBUCKET_URL}"
        }

        stages {
            stage('Checkout') {
                steps {
                    script {
                        // Version computation reads every tag, so a shallow
                        // clone or a tagless fetch silently produces 0.0.1.
                        checkout([
                            $class: 'GitSCM',
                            branches: scm.branches,
                            userRemoteConfigs: scm.userRemoteConfigs,
                            extensions: [[$class: 'CloneOption', shallow: false, noTags: false, depth: 0]]
                        ])
                        env.SDD = sddScripts()
                    }
                }
            }

            stage('Compute version') {
                steps {
                    script {
                        def out = sh(returnStdout: true,
                            script: "${env.SDD}/release-version.sh --service ${service} --json").trim()
                        echo out
                        def v = readJSON text: out
                        env.RELEASE = v.release.toString()
                        env.VERSION = v.next ?: ''
                        env.TAG = v.tag ?: ''
                        env.KEYS = (v.keys ?: []).join(' ')
                        if (env.RELEASE != 'true') {
                            echo 'No conventional commits since the last tag - nothing to release.'
                        }
                        currentBuild.displayName = env.RELEASE == 'true' ? "${service} ${env.VERSION}" : "no release"
                    }
                }
            }

            stage('Guard: hotfixes forward-ported') {
                when { environment name: 'RELEASE', value: 'true' }
                steps {
                    // A hotfix branches from a production tag. Releasing from
                    // main without forward-porting it silently reverts the fix,
                    // so fail loudly here instead.
                    sh """
                        missing=0
                        for tag in \$(git tag --list '${service}-*'); do
                          if ! git merge-base --is-ancestor "\$tag" HEAD; then
                            echo "ERROR: \$tag is not an ancestor of main - forward-port the hotfix first"
                            missing=1
                          fi
                        done
                        exit \$missing
                    """
                }
            }

            stage('Build and push') {
                when { environment name: 'RELEASE', value: 'true' }
                steps {
                    script {
                        if (cfg.build) {
                            // The repo knows how to build itself; we only own
                            // the version it is built under.
                            cfg.build(env.VERSION)
                        } else {
                            withCredentials([usernamePassword(credentialsId: regCred,
                                    usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS')]) {
                                sh """
                                    echo "\$REG_PASS" | docker login ${registry} -u "\$REG_USER" --password-stdin
                                    docker build -t ${registry}/${service}:${env.VERSION} \\
                                                 -t ${registry}/${service}:${env.VERSION}-${env.GIT_COMMIT.take(8)} .
                                    docker push ${registry}/${service}:${env.VERSION}
                                    docker push ${registry}/${service}:${env.VERSION}-${env.GIT_COMMIT.take(8)}
                                """
                            }
                        }
                        // GitOps pins the digest, never the tag - a tag can be
                        // moved, a digest cannot.
                        env.DIGEST = sh(returnStdout: true, script: """
                            docker inspect --format='{{index .RepoDigests 0}}' ${registry}/${service}:${env.VERSION} \\
                              | cut -d'@' -f2
                        """).trim()
                        echo "digest: ${env.DIGEST}"
                    }
                }
            }

            stage('Tag') {
                when { environment name: 'RELEASE', value: 'true' }
                steps {
                    withCredentials([string(credentialsId: bbCred, variable: 'BITBUCKET_TOKEN')]) {
                        sh """
                            git config user.name  'jenkins-release'
                            git config user.email 'jenkins@${env.SDD_MAIL_DOMAIN ?: 'localhost'}'
                            ${env.SDD}/release-version.sh --service ${service} --tag
                            git -c http.extraHeader="Authorization: Bearer \$BITBUCKET_TOKEN" \\
                                push origin ${env.TAG}
                        """
                    }
                }
            }

            stage('Release notes') {
                when { environment name: 'RELEASE', value: 'true' }
                steps {
                    // Bitbucket has no Releases feature. The notes live in the
                    // annotated tag message (written by --tag above) and on the
                    // Jira version, which is what non-engineers actually read.
                    script {
                        def notes = sh(returnStdout: true,
                            script: "${env.SDD}/release-version.sh --service ${service} --notes").trim()
                        echo notes
                        writeFile file: "release-notes-${env.VERSION}.md", text: notes
                        archiveArtifacts artifacts: "release-notes-${env.VERSION}.md", allowEmptyArchive: true
                    }
                }
            }

            stage('Stamp Jira Fix Versions') {
                when { environment name: 'RELEASE', value: 'true' }
                steps {
                    withCredentials([string(credentialsId: jiraCred, variable: 'JIRA_TOKEN')]) {
                        sh """
                            ${env.SDD}/jira-release.sh \\
                              --service ${service} \\
                              --version ${env.VERSION} \\
                              --keys "${env.KEYS}" \\
                              --notes-file release-notes-${env.VERSION}.md
                        """
                    }
                }
            }

            stage('Ask GitOps to roll dev') {
                when { environment name: 'RELEASE', value: 'true' }
                steps {
                    build job: gitopsJob, wait: false, parameters: [
                        string(name: 'SERVICE', value: service),
                        string(name: 'VERSION', value: env.VERSION),
                        string(name: 'DIGEST', value: env.DIGEST),
                        string(name: 'TARGET_ENV', value: 'dev'),
                        string(name: 'SOURCE_ENV', value: ''),
                        string(name: 'KEYS', value: env.KEYS)
                    ]
                }
            }
        }

        post {
            always {
                script {
                    def state = currentBuild.currentResult == 'SUCCESS' ? 'SUCCESSFUL' : 'FAILED'
                    withCredentials([string(credentialsId: bbCred, variable: 'BITBUCKET_TOKEN')]) {
                        sh """
                            . ${env.SDD}/lib/bitbucket.sh
                            bb_build_status "${env.GIT_COMMIT}" "${state}" "sdd-release" \\
                              "SDD release" "${env.BUILD_URL}" "${service} ${env.VERSION ?: 'no release'}" || true
                        """
                    }
                }
            }
            cleanup { cleanWs() }
        }
    }
}
