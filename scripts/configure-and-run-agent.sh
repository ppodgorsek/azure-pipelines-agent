#!/bin/bash

set -ex

echo "Starting the Azure Pipelines agent..."

if [ -n "${AZURE_DEVOPS_AGENT_NAME}" ]
then
  echo "Using a predefined agent name"
  AGENT_NAME="${AZURE_DEVOPS_AGENT_NAME}"
else
  echo "Using the host name as the agent name"
  AGENT_NAME="${HOSTNAME}"
fi

echo "Configuring the '${AGENT_NAME}' agent"

${AGENT_WORK_DIR}/config.sh \
    --unattended \
    --replace \
    --work _work \
    --acceptTeeEula \
    --url "${AZURE_DEVOPS_URL}" \
    --auth PAT \
    --token "${AZURE_DEVOPS_TOKEN}" \
    --agent "${AGENT_NAME}" \
    --pool "${AZURE_DEVOPS_AGENT_POOL}"

echo "Agent has been configured successfully!"

if [ "${AZURE_DEVOPS_AGENT_PLACEHOLDER_MODE}" == "true" ]
then
  # The placeholder mode allows to initialise a pool of self-hosted agents
  # See https://github.com/Azure-Samples/container-apps-ci-cd-runner-tutorial/blob/main/azure-pipelines-agent/start.sh
  echo "Running in placeholder mode, skipping running the agent"
else
  # To be aware of TERM and INT signals call run.sh
  echo "Running the agent with the --once flag, this will shut down the agent after the build is executed"
  ${AGENT_WORK_DIR}/run.sh --once
fi

echo "The agent ran successfully"
