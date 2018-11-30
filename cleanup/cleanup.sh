#!/usr/bin/env bash

IMAGE_NAME=$1

set -e -o pipefail -u

GIT_COMMIT_LIMIT=${KUBECTL_PLUGINS_LOCAL_FLAG_GIT_COMMIT_LIMIT}
GIT_REPO_PATH=${KUBECTL_PLUGINS_LOCAL_FLAG_GIT_REPO_PATH}
FORCE=${KUBECTL_PLUGINS_LOCAL_FLAG_FORCE}
KEEP=${KUBECTL_PLUGINS_LOCAL_FLAG_KEEP}
NAMESPACE=${KUBECTL_PLUGINS_CURRENT_NAMESPACE}
oc="${KUBECTL_PLUGINS_CALLER} -n ${NAMESPACE}"

get_commit_list() {
    set -e
    # all commits except HEAD in the Git repository
    git --git-dir "${GIT_REPO_PATH}"/.git --work-tree "${GIT_REPO_PATH}" rev-list --max-count "${GIT_COMMIT_LIMIT}" --date-order HEAD~
}

get_imagestreamtags() {
    set -e
    local imagestream_path='{range .status.tags[*]}{.tag}{"\n"}{end}'

    ${oc} get imagestream "${IMAGE_NAME}" -o jsonpath="${imagestream_path}" | sort --unique
}

get_active_imagestreamtags() {
    set -e
    local images_in_dc_rc_sset
    local images_in_pod_cont
    local images_in_pod_init
    local images_in_cron

    local dc_rc_sfs_path='{range .items[*]}{.spec.template.spec.containers[*].image}{"\n"}{end}'
    local pod_cont_path='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}'
    local pod_init_path='{range .items[*]}{.spec.initContainers[*].image}{"\n"}{end}'
    local cron_path='{range .items[*]}{.spec.jobTemplate.spec.template.spec.containers[*].image}{"\n"}{end}'

    images_in_dc_rc_sset=$(${oc} get dc,rc,statefulset -o jsonpath="${dc_rc_sfs_path}")
    images_in_pod_cont=$(${oc} get pod -o jsonpath="${pod_cont_path}")
    images_in_pod_init=$(${oc} get pod -o jsonpath="${pod_init_path}")
    images_in_cron=$(${oc} get cronjob -o jsonpath="${cron_path}")

    echo "${images_in_dc_rc_sset}" \
         "${images_in_pod_cont}" \
         "${images_in_pod_init}" \
         "${images_in_cron}" \
         | xargs | tr ' ' '\n' \
         | grep "/${IMAGE_NAME}:" \
         | sed "s#.*/${NAMESPACE}/${IMAGE_NAME}:##" \
         | sort --unique
}

get_inactive_imagestreamtags() {
    set -e
    local all_tags
    local all_active

    all_tags=$(get_imagestreamtags)
    all_active=$(get_active_imagestreamtags)

    # all_inactive := all_tags - all_active
    comm -23 \
        <(echo "${all_tags}" | tr ' ' '\n') \
        <(echo "${all_active}" | tr ' ' '\n')
}

get_deletion_candidates() {
    set -e
    local commit_list
    local inactive_istags
    local deletion_candidates

    commit_list=($(get_commit_list))
    inactive_istags=($(get_inactive_imagestreamtags))
    deletion_candidates=()

    if [[ ${#commit_list[@]} -gt 0 ]] && [[ ${#inactive_istags[@]} -gt 0 ]]; then
        # select all inactive images tagged with one of the commits
        for commit_hash in "${commit_list[@]}"; do
            for candidate in "${inactive_istags[@]}"; do
                if [[ ${candidate} == "${commit_hash}" ]]; then
                    deletion_candidates+=("${IMAGE_NAME}:${candidate}")
                fi
            done
        done
    fi

    if [[ ${#deletion_candidates[@]} -gt 0 ]]; then
        # strip out the <KEEP> youngest images we want to keep
        echo "${deletion_candidates[@]}" | tr ' ' '\n' | tail -n "+$(( KEEP+1 ))"
    fi
}

main() {
    test -z "${IMAGE_NAME}" && {
        echo 'Image name required. Please specify as first argument.'
        echo
        ${oc} get imagestream -o custom-columns="AVAILABLE IMAGES IN ${NAMESPACE}:{.metadata.name}"
        exit 0
    }
    test -z "${GIT_REPO_PATH}" && {
        echo 'Path required. Please use -p to specify the Git repository.'
        exit 0
    }

    local candidates
    local candidate_count

    echo "Comparing commits from ${GIT_REPO_PATH} in namespace ${NAMESPACE}"
    candidates=($(get_deletion_candidates))
    candidate_count=${#candidates[@]}

    if [[ ${candidate_count} == 0 ]]; then
        echo 'No image tags found for deletion.'
        exit 0
    else
        echo "${candidate_count} image tags found for deletion:"
        for image_tag in "${candidates[@]}"; do
            echo "- $image_tag"
        done
    fi

    if [[ ${FORCE} != 'y' ]]; then
        read -p "Delete ${candidate_count} image tags? (y/N) " -r FORCE
    fi
    if [[ ${FORCE} == 'y' ]]; then
        echo "Deleting ${candidate_count} image tags ..."
        ${oc} delete istag --ignore-not-found "${candidates[@]}"
    else
        echo 'Nothing was deleted.'
    fi
}

main
