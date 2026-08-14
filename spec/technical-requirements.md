# Technical Requirements

## Container Provider

- Containers must run rootless, which is why podman is the provider and docker is not: docker cannot do it on macos.
