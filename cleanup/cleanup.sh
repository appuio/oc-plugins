#!/bin/bash

set -e

GIT_REPO_PATH=${KUBECTL_PLUGINS_LOCAL_FLAG_GIT_REPO_PATH}
NAMESPACE=${KUBECTL_PLUGINS_GLOBAL_FLAG_NAMESPACE:-default}
KEEP=${KUBECTL_PLUGINS_LOCAL_FLAG_KEEP}
FROM_HEAD=$(( KEEP+1 ))

# all commits except HEAD in the Git repository
COMMIT_LIST=$(git -C ${GIT_REPO_PATH} rev-list --author-date-order HEAD | tail -n "+2")

DELETION_CANDIDATES=$(oc get istag -n ${NAMESPACE} \
    -o jsonpath='{.items[*].metadata.name}' \
    --sort-by .metadata.creationTimestamp \
    | tr ' ' '\n' | tail -n "+${FROM_HEAD}")

for commit in ${COMMIT_LIST}; do
    for candidate in ${DELETION_CANDIDATES}; do
        # remove all images ending with commit SHA
        if [[ ${candidate} == *${commit} ]]; then
            oc delete istag -n ${NAMESPACE} --ignore-not-found ${candidate}
        fi
    done
done
