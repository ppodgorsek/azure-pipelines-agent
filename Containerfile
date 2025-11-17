FROM docker.io/docker:28-dind

LABEL authors="Paul Podgorsek"
LABEL description="An agent for Azure Pipelines, with Docker-in-Docker, git, Java and Maven enabled."

ENV AGENT_USER_NAME="azure-pipeline-agent"
ENV AGENT_WORK_DIR="/opt/pipeline-agent"

ENV AZURE_DEVOPS_AGENT_PLACEHOLDER_MODE="false"
ENV AZURE_DEVOPS_AGENT_POOL="Default"
ENV AZURE_DEVOPS_AGENT_NAME=""
ENV AZURE_DEVOPS_AGENT_VERSION="4.264.2"

# Agent capabilities
ENV docker="enabled"
ENV git="enabled"
ENV java="enabled"
ENV maven="enabled"

RUN apk --no-cache upgrade \
  && apk --no-cache add \
    # Install dependencies for cryptography due to https://github.com/pyca/cryptography/issues/5771
    cargo \
    curl \
    gcc \
    git \
    openjdk21 \
    make \
    maven \
    python3 \
    py3-pip \
    rust \
    unzip \
    wget \
    which \
    zip

# Create directories for the agent files
RUN mkdir ${AGENT_WORK_DIR} \
  \
  # Download and unpack tarball
  && curl -L https://download.agent.dev.azure.com/agent/${AZURE_DEVOPS_AGENT_VERSION}/vsts-agent-${AGENT_PLATFORM:-linux-x64}-${AZURE_DEVOPS_AGENT_VERSION}.tar.gz -o /tmp/agent.tar.gz \
  && tar zxf /tmp/agent.tar.gz -C ${AGENT_WORK_DIR} \
  && rm -f /tmp/agent.tar.gz \
  \
  # Create user and assign ownership
  && addgroup -S ${AGENT_USER_NAME} \
  && adduser -S ${AGENT_USER_NAME} -G ${AGENT_USER_NAME} \
  && chown -R ${AGENT_USER_NAME} ${AGENT_WORK_DIR}

WORKDIR ${AGENT_WORK_DIR}

RUN sh ${AGENT_WORK_DIR}/bin/installdependencies.sh

# Prepare binaries to be executed
COPY scripts/configure-and-run-agent.sh ${AGENT_WORK_DIR}/configure-and-run-agent.sh

# Grant the correct permissions
RUN chown ${AGENT_USER_NAME}:${AGENT_USER_NAME} ${AGENT_WORK_DIR}/configure-and-run-agent.sh

USER ${AGENT_USER_NAME}:${AGENT_USER_NAME}

ENTRYPOINT [ "${AGENT_WORK_DIR}/configure-and-run-agent.sh" ]
