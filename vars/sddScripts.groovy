#!/usr/bin/env groovy
/**
 * Make this library's bash scripts available on the agent, and return the path.
 *
 * The scripts live in scripts/ so a human can run them by hand when Jenkins is
 * down - which is a stated requirement, see docs/roles/devops.md. A shared
 * library can only expose resources/, so rather than keeping a second copy
 * that drifts, each pipeline shallow-clones this repo at the library's own ref.
 *
 *   def sdd = sddScripts()
 *   sh "${sdd}/release-version.sh --service backend --json"
 */
def call(Map cfg = [:]) {
    def dir = cfg.dir ?: '.sdd-workflow'
    def ref = cfg.ref ?: env.SDD_LIBRARY_REF ?: 'main'
    def url = cfg.url ?: env.SDD_WORKFLOW_REPO
    if (!url) {
        error 'sddScripts: set SDD_WORKFLOW_REPO (Jenkins global env) to this repo\'s clone URL'
    }

    if (!fileExists("${dir}/scripts/release-version.sh")) {
        sh """
            rm -rf ${dir}
            git clone --depth 1 --branch ${ref} ${url} ${dir}
            chmod +x ${dir}/scripts/*.sh ${dir}/scripts/lib/*.sh
        """
    }
    return "${env.WORKSPACE}/${dir}/scripts"
}
