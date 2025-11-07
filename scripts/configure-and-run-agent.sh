#!/bin/bash

set -ex

if [ -n "${AZURE_DEVOPS_AGENT_NAME}" ]
then
  AGENT_NAME="${AZURE_DEVOPS_AGENT_NAME}"
else
  AGENT_NAME="${HOSTNAME}"
fi

${AGENT_WORK_DIR}/config.sh \
    --replace \
    --work _work \
    --acceptTeeEula \
    --url "${AZURE_DEVOPS_URL}" \
    --auth pat \
    --token "${AZURE_DEVOPS_TOKEN}" \
    --agent "${AGENT_NAME}" \
    --pool "${AZURE_DEVOPS_AGENT_POOL}"

${AGENT_WORK_DIR}/run.sh --once
