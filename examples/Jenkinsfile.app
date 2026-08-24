// Application repo (backend, frontend, common, nginx).
//
// Multibranch pipeline over the repo. Branch builds and pull requests run the
// checks; a push to main releases. Copy this in and change the two names.

@Library('sdd-workflow@main') _

if (env.BRANCH_NAME == 'main') {
    sddRelease(
        service:   'backend',
        registry:  'registry.acme.com/platform',
        gitopsJob: 'gitops/backend-promote'
        // build: { version -> sh "make docker-build VERSION=${version}" }
    )
} else {
    sddPrChecks(
        bitbucketProject: 'PLAT',
        bitbucketRepo:    'backend'
    )
}
