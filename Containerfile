FROM quay.io/podman/stable:v5.6

LABEL authors="Paul Podgorsek"
LABEL description="An agent for Azure Pipelines, with Ansible, git, Java, Maven, .Net, Podman (Docker) + Buildah, Python 3 and Terraform enabled."

ENV AGENT_USER_NAME="podman"
ENV AGENT_WORK_DIR="/opt/pipeline-agent"

ENV AZURE_DEVOPS_AGENT_PLACEHOLDER_MODE="false"
ENV AZURE_DEVOPS_AGENT_POOL="Default"
ENV AZURE_DEVOPS_AGENT_NAME=""
ENV AZURE_DEVOPS_AGENT_VERSION="4.264.2"

ENV ANSIBLE_COLLECTION_AWS_VERSION="10.1.2"
ENV ANSIBLE_COLLECTION_AZURE_VERSION="v3.11.0"
ENV ANSIBLE_COLLECTION_GCP_VERSION="v1.10.2"
ENV DOTNET_VERSION="10.0"
ENV JAVA_VERSION="21"
ENV TERRAFORM_VERSION="1.13.5"

# Agent capabilities
ENV ansible="enabled"
ENV docker="enabled"
ENV dotnet="enabled"
ENV git="enabled"
ENV java="enabled"
ENV maven="enabled"
ENV terraform="enabled"

# Don't include container-selinux and remove directories used by DNF that are just taking up space.
RUN dnf upgrade -y > /dev/null \
  && dnf install -y \
    --exclude container-selinux \
    automake \
    buildah \
    # Install dependencies for cryptography due to https://github.com/pyca/cryptography/issues/5771
    cargo \
    curl \
    dnf-plugins-core \
    dotnet-sdk-${DOTNET_VERSION} \
    gcc \
    gcc-c++ \
    git \
    java-${JAVA_VERSION}-openjdk \
    make \
    maven \
    openssl \
    openssl-devel \
    podman-docker \
    python3 \
    python3-devel \
    python3-pip \
    rust \
    unzip \
    wget \
    which \
    zip \
  && dnf clean all \
  && rm -rf /var/cache /var/log/dnf* /var/log/yum.*

# Create directories for the agent files
RUN mkdir ${AGENT_WORK_DIR} \
  && chown -R ${AGENT_USER_NAME}:${AGENT_USER_NAME} ${AGENT_WORK_DIR} \
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
RUN chown ${AGENT_USER_NAME}:${AGENT_USER_NAME} ${AGENT_WORK_DIR}/configure-and-run-agent.sh

# Install the latest version of Ansible, along with the collections for major cloud providers
RUN pip3 install ansible-core --upgrade \
  && pip3 install cryptography \
  && pip3 install -r https://raw.githubusercontent.com/ansible-collections/amazon.aws/${ANSIBLE_COLLECTION_AWS_VERSION}/requirements.txt \
  # azure-iot-hub relies on the outdated uamqp library, which doesn't work with recent Python versions
  && curl https://raw.githubusercontent.com/ansible-collections/azure/${ANSIBLE_COLLECTION_AZURE_VERSION}/requirements.txt | grep -ivE "azure-iot-hub|azure-mgmt-iothub" > azure-requirements.txt \
  && pip3 install -r azure-requirements.txt \
  && pip3 install -r https://raw.githubusercontent.com/ansible-collections/google.cloud/${ANSIBLE_COLLECTION_GCP_VERSION}/requirements.txt

# Terraform
# Official documentation: https://developer.hashicorp.com/terraform/install
RUN dnf config-manager addrepo --from-repofile=https://rpm.releases.hashicorp.com/fedora/hashicorp.repo \
  && dnf install -y terraform-${TERRAFORM_VERSION}* \
  && dnf clean all

USER ${AGENT_USER_NAME}

ENTRYPOINT [ "./configure-and-run-agent.sh" ]
