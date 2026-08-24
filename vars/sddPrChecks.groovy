#!/usr/bin/env groovy
/**
 * The input validation for everything downstream. Runs on every pull request
 * in an application repo, and reports a build status Bitbucket can require as
 * a merge check.
 *
 *   @Library('sdd-workflow@main') _
 *   sddPrChecks(bitbucketProject: 'PLAT', bitbucketRepo: 'backend')
 *
 * The release pipeline derives version bumps from commit types and Jira Fix
 * Versions from issue keys in the commit range. Both are only as good as the
 * squash commit, and in Bitbucket the squash commit is built from the pull
 * request title and description. So this checks the title, and repairs the
 * description when the key is missing rather than failing the author over a
 * convention a script can satisfy.
 *
 * Set the repository's merge strategy to **Squash only** or none of this
 * holds. See docs/release.md#commit-and-pr-conventions.
 */
def call(Map cfg = [:]) {
    def bbProject = cfg.bitbucketProject ?: error('sddPrChecks: "bitbucketProject" is required')
    def bbRepo = cfg.bitbucketRepo ?: error('sddPrChecks: "bitbucketRepo" is required')
    def bbCred = cfg.bitbucketCredentials ?: 'sdd-bitbucket-token'
    def jiraCred = cfg.jiraCredentials ?: 'sdd-jira-token'

    // Bots have no story, and chores are deliberately outside the SDD metric.
    // This is the only exemption the checks make. Renovate is the bot here -
    // Dependabot does not support Bitbucket Data Center.
    def botBranch = ~/^renovate\/.*/
    def titleRe = ~/^(feat|fix|perf|refactor|docs|test|build|ci|chore|revert)(\([a-z0-9._-]+\))?!?: .+/
    def branchRe = ~/^([A-Z][A-Z0-9]+-[0-9]+\/)?[A-Z][A-Z0-9]+-[0-9]+-[a-z0-9][a-z0-9-]*$/

    pipeline {
        agent { label cfg.agent ?: 'linux' }

        options { timestamps() }

        environment {
            BITBUCKET_URL = "${env.SDD_BITBUCKET_URL}"
            BITBUCKET_PROJECT = "${bbProject}"
            BITBUCKET_REPO = "${bbRepo}"
            JIRA_URL = "${env.SDD_JIRA_URL}"
            JIRA_EMAIL = "${env.SDD_JIRA_EMAIL ?: ''}"
        }

        stages {
            stage('Checkout') {
                steps {
                    // The spec-before-code check needs the merge base, so the
                    // full history has to be here.
                    checkout([
                        $class: 'GitSCM',
                        branches: scm.branches,
                        userRemoteConfigs: scm.userRemoteConfigs,
                        extensions: [[$class: 'CloneOption', shallow: false, noTags: false, depth: 0]]
                    ])
                    script { env.SDD = sddScripts() }
                }
            }

            stage('Branch name') {
                steps {
                    script {
                        def branch = env.CHANGE_BRANCH ?: env.BRANCH_NAME
                        if (branch ==~ botBranch) {
                            echo "bot branch ${branch} - exempt"
                            return
                        }
                        if (!(branch ==~ branchRe)) {
                            error """Branch must be PROJ-123-slug, or PROJ-123/PROJ-124-slug for a multi-repo story.
  got: ${branch}
  see: docs/jira-sdd-mapping.md#branch-naming"""
                        }
                        echo "branch ok: ${branch}"
                    }
                }
            }

            stage('Conventional PR title') {
                when { expression { env.CHANGE_ID } }
                steps {
                    script {
                        def title = env.CHANGE_TITLE ?: ''
                        if ((env.CHANGE_BRANCH ?: '') ==~ botBranch) { return }
                        if (!(title ==~ titleRe)) {
                            error """Pull request title must be a conventional commit.
  got:      ${title}
  expected: feat(auth): add SSO callback endpoint
  types:    feat fix perf refactor docs test build ci chore revert
  breaking: append ! before the colon -> feat(api)!: ..."""
                        }
                        echo "title ok: ${title}"
                    }
                }
            }

            stage('Jira key survives the squash') {
                when { expression { env.CHANGE_ID } }
                steps {
                    script {
                        def branch = env.CHANGE_BRANCH ?: ''
                        if (branch ==~ botBranch) { return }

                        def keys = (branch =~ /[A-Z][A-Z0-9]+-[0-9]+/).collect { it }.unique()
                        withCredentials([string(credentialsId: bbCred, variable: 'BITBUCKET_TOKEN')]) {
                            def desc = sh(returnStdout: true, script: """
                                . ${env.SDD}/lib/bitbucket.sh
                                bb_pr_get ${env.CHANGE_ID} | jq -r '.description // ""'
                            """).trim()

                            def missing = keys.findAll { !desc.contains(it) }
                            if (!missing) {
                                echo 'every key from the branch is already in the description'
                                return
                            }
                            echo "appending to the pull request description: ${missing.join(' ')}"
                            def updated = (desc ? desc + '\n\n' : '') + missing.join(' ')
                            writeFile file: '.pr-description', text: updated
                            sh """
                                . ${env.SDD}/lib/bitbucket.sh
                                bb_pr_set_description ${env.CHANGE_ID} "\$(cat .pr-description)"
                            """
                        }
                    }
                }
            }

            stage('SDD metric') {
                steps {
                    withCredentials([string(credentialsId: jiraCred, variable: 'JIRA_TOKEN')]) {
                        sh """
                            export SDD_BASE_REF=origin/${env.CHANGE_TARGET ?: 'main'}
                            ${env.SDD}/check-sdd.sh
                        """
                    }
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
                            bb_build_status "${env.GIT_COMMIT}" "${state}" "sdd-pr-checks" \\
                              "SDD pull request checks" "${env.BUILD_URL}" "" || true
                        """
                    }
                }
            }
            cleanup { cleanWs() }
        }
    }
}
