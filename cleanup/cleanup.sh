#!/bin/bash

set -e -o pipefail -u

GIT_REPO_PATH=${KUBECTL_PLUGINS_LOCAL_FLAG_GIT_REPO_PATH}
KEEP=${KUBECTL_PLUGINS_LOCAL_FLAG_KEEP}
FROM_HEAD=$(( KEEP+1 ))
NAMESPACE=${KUBECTL_PLUGINS_CURRENT_NAMESPACE}
oc="${KUBECTL_PLUGINS_CALLER} -n ${NAMESPACE}"

get_commit_list() {
    # all commits except HEAD in the Git repository
    git -C ${GIT_REPO_PATH} rev-list --author-date-order HEAD | tail -n "+2"
}

get_active_images() {
    local dc_rc_sfs_path='{range .items[*]}{.spec.template.spec.containers[*].image}{"\n"}{end}'
    local pod_cont_path='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}'
    local pod_init_path='{range .items[*]}{.spec.initContainers[*].image}{"\n"}{end}'
    local cron_path='{range .items[*]}{.spec.jobTemplate.spec.template.spec.containers[*].image}{"\n"}{end}'

    local images_in_dc_rc_sset=$(${oc} get dc,rc,statefulset -o jsonpath="${dc_rc_sfs_path}")
    local images_in_pod_cont=$(${oc} get pod -o jsonpath="${pod_cont_path}")
    local images_in_pod_init=$(${oc} get pod -o jsonpath="${pod_init_path}")
    local images_in_cron=$(${oc} get cronjob -o jsonpath="${cron_path}")

    echo "${images_in_dc_rc_sset}" \
         "${images_in_pod_cont}" \
         "${images_in_pod_init}" \
         "${images_in_cron}" | sort --unique
}

get_deletion_candidates() {
    local istags_path='{range .items[*]}{.metadata.name}{"\n"}{end}'
    local sort_by_date='--sort-by .metadata.creationTimestamp'

    local all_tags=$(${oc} get istag -o jsonpath="${istags_path}" ${sort_by_date} \
                   | tail -n "+${FROM_HEAD}" | sort --unique)

    local all_active=$(get_active_images)

    # all_inactive := all_tags - all_active
    comm -23 <(echo ${all_tags}) <(echo ${all_active})
}

main() {
    test -z ${GIT_REPO_PATH} && {
        echo 'Path required. Please use -p to specify the Git repository.'
        exit 0
    }

    echo "Comparing commits from ${GIT_REPO_PATH} in namespace ${NAMESPACE} .."

    local commit_list=($(get_commit_list))
    local deletion_candidates=($(get_deletion_candidates))
    local counter=0

    echo "Scanning ${#deletion_candidates[@]} image tags" \
         "against ${#commit_list[@]} commits ..."

    for commit_hash in ${commit_list[*]}; do
        for candidate in ${deletion_candidates[*]}; do
            # remove all images ending with commit SHA
            if [[ ${candidate} == *${commit_hash} ]]; then
                echo "Deleting $candidate ..."
                ${oc} delete istag --ignore-not-found ${candidate}
                (( counter++ ))
            fi
        done
    done

    echo "${counter} image tags deleted."
    exit 0
}

main
