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

if [ "${AZURE_DEVOPS_AGENT_PLACEHOLDER_MODE}" == "true" ]
then
  # The placeholder mode allows to initialise a pool of self-hosted agents
  # See https://github.com/Azure-Samples/container-apps-ci-cd-runner-tutorial/blob/main/azure-pipelines-agent/start.sh
  echo 'Running in placeholder mode, skipping running the agent'
else
  # To be aware of TERM and INT signals call run.sh
  # Running it with the --once flag at the end will shut down the agent after the build is executed
  ${AGENT_WORK_DIR}/run.sh --once
fi
