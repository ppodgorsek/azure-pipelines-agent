FROM quay.io/podman/stable:v5.6

LABEL authors="Paul Podgorsek"
LABEL description="An agent for Azure Pipelines, with git, Java, Maven and Podman (Docker) enabled."

ENV AGENT_USER_NAME="podman"
ENV AGENT_WORK_DIR="/opt/pipeline-agent"

ENV AZURE_DEVOPS_AGENT_PLACEHOLDER_MODE="false"
ENV AZURE_DEVOPS_AGENT_POOL="Default"
ENV AZURE_DEVOPS_AGENT_NAME=""
ENV AZURE_DEVOPS_AGENT_VERSION="4.264.2"

ENV JAVA_VERSION="21"

# Agent capabilities
ENV docker="enabled"
ENV git="enabled"
ENV java="enabled"
ENV maven="enabled"

# Don't include container-selinux and remove directories used by DNF that are just taking up space.
RUN dnf upgrade -y > /dev/null \
  && dnf install -y \
    --exclude container-selinux \
    buildah \
    # Install dependencies for cryptography due to https://github.com/pyca/cryptography/issues/5771
    cargo \
    curl \
    gcc \
    git \
    java-${JAVA_VERSION}-openjdk \
    make \
    maven \
    podman-docker \
    python3 \
    python3-pip \
    rust \
    unzip \
    wget \
    which \
    zip \
  && dnf clean all \
  && rm -rf /var/cache /var/log/dnf* /var/log/yum.*

ADD https://raw.githubusercontent.com/containers/image_build/main/podman/containers.conf /etc/containers/containers.conf
ADD https://raw.githubusercontent.com/containers/image_build/main/podman/podman-containers.conf /home/${AGENT_USER_NAME}/.config/containers/containers.conf

# Create directories for the agent files
RUN mkdir ${AGENT_WORK_DIR} \
  \
  # Download and unpack tarball
  && curl -L https://download.agent.dev.azure.com/agent/${AZURE_DEVOPS_AGENT_VERSION}/vsts-agent-${AGENT_PLATFORM:-linux-x64}-${AZURE_DEVOPS_AGENT_VERSION}.tar.gz -o /tmp/agent.tar.gz \
  && tar zxf /tmp/agent.tar.gz -C ${AGENT_WORK_DIR} \
  && rm -f /tmp/agent.tar.gz \
  \
  && chmod 644 /etc/containers/containers.conf \
  && chmod 644 /home/${AGENT_USER_NAME}/.config/containers/containers.conf \
  && chown -R ${AGENT_USER_NAME}:${AGENT_USER_NAME} ${AGENT_WORK_DIR} \
  && chown -R ${AGENT_USER_NAME}:${AGENT_USER_NAME} /home/${AGENT_USER_NAME}

VOLUME /var/lib/containers
VOLUME /home/${AGENT_USER_NAME}/.local/share/containers

WORKDIR ${AGENT_WORK_DIR}

RUN sh ${AGENT_WORK_DIR}/bin/installdependencies.sh

# Prepare binaries to be executed
COPY scripts/configure-and-run-agent.sh ${AGENT_WORK_DIR}/configure-and-run-agent.sh

# Grant the correct permissions
RUN chown ${AGENT_USER_NAME}:${AGENT_USER_NAME} ${AGENT_WORK_DIR}/configure-and-run-agent.sh

USER ${AGENT_USER_NAME}

ENTRYPOINT [ "${AGENT_WORK_DIR}/configure-and-run-agent.sh" ]
