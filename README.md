# Azure Pipelines agent in Docker

## Table of contents

* [What is it?](#what-is-it)
* [Versioning](#versioning)
* [Running the container](#running-the-container)
    * [Changing the name of the agent pool](#changing-agent-pool-name)
    * [Initialising a self-hosted agent pool via the placeholder mode](#placeholder-mode)
    * [Overriding the agent name](#overriding-agent-name)
* [Running the image on different platforms](#platforms)
    * [Azure Container Apps](#platform-azure-container-apps)
* [Please contribute!](#please-contribute)

-----

<a name="what-is-it"></a>

## What is it?

This project consists of an Azure Pipelines agent container image, including several useful build and deployment tools.

This image contains:
* Ansible (with its major cloud collections)
* gcc
* git
* Helm + kubectl
* Java 21
* make
* Maven
* .Net 10
* Podman (with an alias for `docker`) + Buildah
* PostgreSQL
* Python 3
* Rust
* Terraform

Running Podman inside a container is based on RedHat's [excellent article](https://www.redhat.com/en/blog/podman-inside-container), the official [Podman tutorial for rootless executions](https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md) and [Podman's official container image](https://quay.io/repository/podman/stable?tab=info).

> [!WARNING]  
> As mentioned in those articles, running Podman-in-Docker or Docker-in-Docker won't be possible on platforms such as Azure Container Apps where a privileged execution isn't possible. It is however possible in Kubernetes or on machines where such privileged execution is allowed.

> [!TIP]
> On platforms where privileged execution is impossible, one option can be to split the build pipeline into multiple stages and to run any container build/run steps on a Microsoft-hosted agent while the rest of the pipeline runs on a self-hosted agent.

<a name="versioning"></a>

## Versioning

The versioning of this image follows the one of the [official Azure Pipelines agent](https://github.com/microsoft/azure-pipelines-agent):

* Major, minor and patch versions match the one of the Azure Pipelines agent
* Build version is specific to this project (allows to update the versions of the other dependencies)

<a name="running-the-container"></a>

## Running the container

This container can be run using the following command:

```sh
docker run --rm \
    -e AZURE_DEVOPS_TOKEN="CHANGEME" \
    -e AZURE_DEVOPS_URL="CHANGEME" \
    docker.io/ppodgorsek/azure-pipelines-agent:<version>
```

A personal access token can be generated in Azure DevOps, and should be set using the `AZURE_DEVOPS_TOKEN` variable. Please note that this could also be a token from a service principal.

The `AZURE_DEVOPS_URL` variable represents the URL of your organisation's instance, for example `https://dev.azure.com/<organisation ID>`.

<a name="changing-agent-pool-name"></a>

### Changing the name of the agent pool

By default, the agent pool name is simply `Default`.

This can be changed if needed via the `AZURE_DEVOPS_AGENT_POOL` environment variable:

```sh
docker run --rm \
    -e AZURE_DEVOPS_AGENT_POOL='Azure Container Apps' \
    -e AZURE_DEVOPS_TOKEN="CHANGEME" \
    -e AZURE_DEVOPS_URL="CHANGEME" \
    docker.io/ppodgorsek/azure-pipelines-agent:<version>
```

<a name="placeholder-mode"></a>

### Initialising a self-hosted agent pool using the placeholder mode

In order to be used by pipelines, self-hosted agent pools must be initialised by running an agent at least once within them. This allows Azure Pipelines to determine the agent version, its capabilities and other metadata to allocate build jobs.

> [!NOTE]  
> Placeholders are only relevant when deploying the agent to services which don't have at least one continuously-running instance, such as Azure Container Apps.

After creating a new agent pool, the placeholder mode can be enabled using the `AZURE_DEVOPS_AGENT_PLACEHOLDER_MODE` environment variable:

```sh
docker run --rm \
    -e AZURE_DEVOPS_AGENT_PLACEHOLDER_MODE="true" \
    -e AZURE_DEVOPS_AGENT_POOL="Azure Container Apps" \
    -e AZURE_DEVOPS_TOKEN="CHANGEME" \
    -e AZURE_DEVOPS_URL="CHANGEME" \
    docker.io/ppodgorsek/azure-pipelines-agent:<version>
```

Agents run using the placeholder mode will follow a very simple lifecycle:
1. Configure the agent,
2. Register the agent in the Azure DevOps pool,
2. Terminate.

> [!IMPORTANT]  
> Such placeholder agents cannot process any build jobs, the environment variable should therefore only be used for the initial placeholder agent, not all agents.

<a name="overriding-agent-name"></a>

### Overriding the agent name

By default, the agent name within the pool will be its host name.

This can however be overriden if needed, by relying on the `AZURE_DEVOPS_AGENT_NAME` environment variable:

```sh
docker run --rm \
    -e AZURE_DEVOPS_AGENT_NAME='custom-agent' \
    -e AZURE_DEVOPS_TOKEN="CHANGEME" \
    -e AZURE_DEVOPS_URL="CHANGEME" \
    docker.io/ppodgorsek/azure-pipelines-agent:<version>
```

<a name="platforms"></a>

## Running the image on different platforms

<a name="platform-azure-container-apps"></a>

### Azure Container Apps

The easiest way to run the agent in Azure is via an Azure Container App Job.

Such jobs can scale up and down according to various metrics and, luckily, one of those metrics is the number of pending jobs in Azure Pipelines.

The Terraform configuration will therefore look as follows:

```tf
# The placeholder job is used to initialise the agent pool
resource "azurerm_container_app_job" "azure_pipelines_agent_placeholder" {
  name                         = "${var.azure_devops_container_app_azure_pipelines_agent_name}-init"
  location                     = azurerm_resource_group.azure_devops.location
  resource_group_name          = azurerm_resource_group.azure_devops.name
  container_app_environment_id = azurerm_container_app_environment.azure_devops.id

  replica_timeout_in_seconds = 300
  replica_retry_limit        = 0

  manual_trigger_config {
    parallelism              = 1
    replica_completion_count = 1
  }

  identity {
    identity_ids = [
      azurerm_user_assigned_identity.azure_devops.id,
    ]
    type = "UserAssigned"
  }

  secret {
    identity            = azurerm_user_assigned_identity.azure_devops.id
    key_vault_secret_id = data.azurerm_key_vault_secret.azure_devops_access_token.id
    name                = var.azure_devops_keyvault_access_token_secret_name
  }

  secret {
    identity            = azurerm_user_assigned_identity.azure_devops.id
    key_vault_secret_id = data.azurerm_key_vault_secret.azure_devops_organisation_url.id
    name                = var.azure_devops_keyvault_organisation_url_secret_name
  }

  # Probes are currently not supported, as no endpoints are exposed
  # https://github.com/microsoft/azure-pipelines-agent/issues/3478
  template {
    container {
      image = var.azure_devops_pipelines_agent_image
      name  = "azure-devops-agent-init"

      cpu    = 2
      memory = "4Gi"

      env {
        name  = "AZURE_DEVOPS_AGENT_POOL"
        value = var.azure_devops_pipelines_agent_pool
      }

      env {
        name  = "AZURE_DEVOPS_AGENT_POOL_PLACEHOLDER_MODE"
        value = "true"
      }

      env {
        name        = "AZURE_DEVOPS_TOKEN"
        secret_name = var.azure_devops_keyvault_access_token_secret_name
      }

      env {
        name        = "AZURE_DEVOPS_URL"
        secret_name = var.azure_devops_keyvault_organisation_url_secret_name
      }
    }
  }
}

resource "azurerm_container_app_job" "azure_pipelines_agent" {
  name                         = var.azure_devops_container_app_azure_pipelines_agent_name
  location                     = azurerm_resource_group.azure_devops.location
  resource_group_name          = azurerm_resource_group.azure_devops.name
  container_app_environment_id = azurerm_container_app_environment.azure_devops.id

  replica_timeout_in_seconds = 7200
  replica_retry_limit        = 0

  event_trigger_config {
    scale {
      max_executions              = 3
      min_executions              = 0
      polling_interval_in_seconds = 30

      rules {
        custom_rule_type = "azure-pipelines"
        metadata = {
          poolName                   = var.azure_devops_pipelines_agent_pool
          targetPipelinesQueueLength = 1
        }
        name = "azure-pipelines-job-queue-length"

        authentication {
          secret_name       = var.azure_devops_keyvault_access_token_secret_name
          trigger_parameter = "personalAccessToken"
        }

        authentication {
          secret_name       = var.azure_devops_keyvault_organisation_url_secret_name
          trigger_parameter = "organizationURL"
        }
      }
    }
  }

  identity {
    identity_ids = [
      azurerm_user_assigned_identity.azure_devops.id,
    ]
    type = "UserAssigned"
  }

  secret {
    identity            = azurerm_user_assigned_identity.azure_devops.id
    key_vault_secret_id = data.azurerm_key_vault_secret.azure_devops_access_token.id
    name                = var.azure_devops_keyvault_access_token_secret_name
  }

  secret {
    identity            = azurerm_user_assigned_identity.azure_devops.id
    key_vault_secret_id = data.azurerm_key_vault_secret.azure_devops_organisation_url.id
    name                = var.azure_devops_keyvault_organisation_url_secret_name
  }

  # Probes are currently not supported, as no endpoints are exposed
  # https://github.com/microsoft/azure-pipelines-agent/issues/3478
  template {
    container {
      image = var.azure_devops_pipelines_agent_image
      name  = "azure-devops-agent"

      cpu    = 2
      memory = "4Gi"

      env {
        name  = "AZURE_DEVOPS_AGENT_POOL"
        value = var.azure_devops_pipelines_agent_pool
      }

      env {
        name        = "AZURE_DEVOPS_TOKEN"
        secret_name = var.azure_devops_keyvault_access_token_secret_name
      }

      env {
        name        = "AZURE_DEVOPS_URL"
        secret_name = var.azure_devops_keyvault_organisation_url_secret_name
      }
    }
  }
}
```

Once deployed, go to the Azure Portal, open the Container App Job named `caj-azure-pipelines-agent-init` and run it manually. The agent pool in Azure DevOps should then show at least one (disconnected) agent within it and the pool will be ready to use.

<a name="please-contribute"></a>

## Please contribute!

Have you found an issue? Do you have an idea for an improvement? Feel free to contribute by submitting it [on the GitHub project](https://github.com/ppodgorsek/azure-pipelines-agent/issues).
