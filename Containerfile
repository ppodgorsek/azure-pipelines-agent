FROM docker.io/ppodgorsek/ansible-awx-ee:24.6.1.4

LABEL authors="Paul Podgorsek"
LABEL description="An agent for Azure Pipelines, with Ansible, git, Helm + kubectl, Java, Maven, .Net, Podman (Docker) + Buildah, PostgreSQL, Python 3 and Terraform enabled."

ENV AGENT_GROUP_ID="1000"
ENV AGENT_USER_ID="1000"
ENV AGENT_USER_NAME="podman"
ENV AGENT_WORK_DIR="/opt/pipeline-agent"

ENV AZURE_DEVOPS_AGENT_PLACEHOLDER_MODE="false"
ENV AZURE_DEVOPS_AGENT_POOL="Default"
ENV AZURE_DEVOPS_AGENT_NAME=""
ENV AZURE_DEVOPS_AGENT_VERSION="4.264.2"

ENV DOTNET_VERSION="10.0"

# Agent capabilities
ENV ansible="enabled"
ENV docker="enabled"
ENV dotnet="enabled"
ENV git="enabled"
ENV helm="enabled"
ENV java="enabled"
ENV maven="enabled"
ENV postgresql="enabled"
ENV terraform="enabled"

USER root

# Don't include container-selinux and remove directories used by DNF that are just taking up space.
RUN dnf upgrade -y > /dev/null \
  && dnf reinstall -y shadow-utils \
  && dnf install -y \
    --exclude container-selinux \
    automake \
    buildah \
    # Install dependencies for cryptography due to https://github.com/pyca/cryptography/issues/5771
    cargo \
    dnf-plugins-core \
    dotnet-sdk-${DOTNET_VERSION} \
    fuse-overlayfs \
    gcc \
    gcc-c++ \
    git \
    make \
    maven \
    openssl-devel \
    podman-docker \
    python3 \
    python3-devel \
    python3-pip \
    rust \
    wget \
    which \
    zip \
  && dnf clean all \
  && rm -rf /var/cache /var/log/dnf* /var/log/yum.*

# Podman

RUN groupadd --gid ${AGENT_GROUP_ID} ${AGENT_USER_NAME} \
  && useradd --gid ${AGENT_GROUP_ID} --uid ${AGENT_USER_ID} ${AGENT_USER_NAME} \
  && echo ${AGENT_USER_NAME}:10000:5000 > /etc/subuid \
  && echo ${AGENT_USER_NAME}:10000:5000 > /etc/subgid

VOLUME /var/lib/containers
VOLUME /home/${AGENT_USER_NAME}/.local/share/containers

ADD https://raw.githubusercontent.com/containers/image_build/main/podman/containers.conf /etc/containers/containers.conf
ADD https://raw.githubusercontent.com/containers/image_build/main/podman/podman-containers.conf /home/${AGENT_USER_NAME}/.config/containers/containers.conf

RUN chown ${AGENT_USER_ID}:${AGENT_GROUP_ID} -R /home/${AGENT_USER_NAME}

# chmod containers.conf and adjust storage.conf to enable Fuse storage.
RUN chmod 644 /etc/containers/containers.conf \
  && sed -i -e 's|^#mount_program|mount_program|g' \
    -e '/additionalimage.*/a "/var/lib/shared",' \
    -e 's|^mountopt[[:space:]]*=.*$|mountopt = "nodev,fsync=0"|g' \
    /etc/containers/storage.conf \
  && mkdir -p /var/lib/shared/overlay-images \
    /var/lib/shared/overlay-layers \
    /var/lib/shared/vfs-images \
    /var/lib/shared/vfs-layers \
  && touch /var/lib/shared/overlay-images/images.lock \
  && touch /var/lib/shared/overlay-layers/layers.lock \
  && touch /var/lib/shared/vfs-images/images.lock \
  && touch /var/lib/shared/vfs-layers/layers.lock

ENV _CONTAINERS_USERNS_CONFIGURED=""

# Create directories for the agent files
RUN mkdir ${AGENT_WORK_DIR} \
  && chown -R ${AGENT_USER_ID}:${AGENT_GROUP_ID} ${AGENT_WORK_DIR} \
  \
  # Download and unpack tarball
  && curl -L https://download.agent.dev.azure.com/agent/${AZURE_DEVOPS_AGENT_VERSION}/vsts-agent-${AGENT_PLATFORM:-linux-x64}-${AZURE_DEVOPS_AGENT_VERSION}.tar.gz -o /tmp/agent.tar.gz \
  && tar zxf /tmp/agent.tar.gz -C ${AGENT_WORK_DIR} \
  && rm -f /tmp/agent.tar.gz

WORKDIR ${AGENT_WORK_DIR}

RUN sh ${AGENT_WORK_DIR}/bin/installdependencies.sh

# Prepare binaries to be executed
COPY scripts/configure-and-run-agent.sh ${AGENT_WORK_DIR}/configure-and-run-agent.sh

# Grant the correct permissions
RUN chown ${AGENT_USER_ID}:${AGENT_GROUP_ID} ${AGENT_WORK_DIR}/configure-and-run-agent.sh

USER ${AGENT_USER_NAME}

ENTRYPOINT [ "./configure-and-run-agent.sh" ]
