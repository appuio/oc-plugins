#!/bin/bash

set -e -o pipefail -u

GIT_REPO_PATH=${KUBECTL_PLUGINS_LOCAL_FLAG_GIT_REPO_PATH}
FORCE=${KUBECTL_PLUGINS_LOCAL_FLAG_FORCE}
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

get_inactive_images() {
    local istags_path='{range .items[*]}{.metadata.name}{"\n"}{end}'
    local sort_by_date='--sort-by .metadata.creationTimestamp'

    local all_tags=$(${oc} get istag -o jsonpath="${istags_path}" ${sort_by_date} \
                   | tail -n "+${FROM_HEAD}" | sort --unique)

    local all_active=$(get_active_images)

    # all_inactive := all_tags - all_active
    comm -23 <(echo ${all_tags}) <(echo ${all_active})
}

get_deletion_candidates() {
    local commit_list=($(get_commit_list))
    local inactive_images=($(get_inactive_images))
    local deletion_candidates=()

    for commit_hash in ${commit_list[*]}; do
        for candidate in ${inactive_images[*]}; do
            # remove all images ending with commit SHA
            if [[ ${candidate} == *${commit_hash} ]]; then
                deletion_candidates+=(${candidate})
            fi
        done
    done

    echo ${deletion_candidates[*]}
}

main() {
    test -z ${GIT_REPO_PATH} && {
        echo 'Path required. Please use -p to specify the Git repository.'
        exit 0
    }

    echo "Comparing commits from ${GIT_REPO_PATH} in namespace ${NAMESPACE} .."
    local candidates=($(get_deletion_candidates))

    if [[ ${#candidates[@]} == 0 ]]; then
        echo 'No image tags found for deletion.'
        exit 0
    else
        echo "${#candidates[@]} image tags found for deletion:"
        for image_tag in ${candidates[*]}; do
            echo "- $image_tag"
        done
    fi

    if [[ ${FORCE} != 'y' ]]; then
        read -p "Delete images tags? (y/N) " FORCE
    fi
    if [[ ${FORCE} == 'y' ]]; then
        echo "Deleting ${#candidates[@]} image tags ..."
        ${oc} delete istag --ignore-not-found ${candidates[*]}
    else
        echo 'Nothing was deleted.'
    fi
}

main
