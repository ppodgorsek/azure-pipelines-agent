# Azure Pipelines agent in Docker

## Table of contents

* [What is it?](#what-is-it)
* [Versioning](#versioning)
* [Running the container](#running-the-container)
    * [Changing the name of the agent pool](#changing-agent-pool-name)
    * [Overriding the agent name](#overriding-agent-name)
* [Please contribute!](#please-contribute)

-----

<a name="what-is-it"></a>

## What is it?

This project consists of a container image containing an Azure Pipelines agent installation.

This image allows to run Docker-in-Docker and also contains:
* gcc
* git
* Java 21
* make
* Maven
* Python 3.9
* Rust

<a name="versioning"></a>

## Versioning

The versioning of this image follows the one of the official Docker-in-Docker image:

* Major version matches the one of Docker-in-Docker
* Minor and patch versions are specific to this project (allows to update the versions of the other dependencies)

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

<a name="please-contribute"></a>

## Please contribute!

Have you found an issue? Do you have an idea for an improvement? Feel free to contribute by submitting it [on the GitHub project](https://github.com/ppodgorsek/azure-pipelines-agent/issues).
