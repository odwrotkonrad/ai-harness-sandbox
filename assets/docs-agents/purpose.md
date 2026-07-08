# Purpose

## What It Is

Local claude session sandbox: a two-node kind cluster (`sandbox`, one
control-plane node for the management plane, one worker node for the data
plane) running persistent per-session pods on the worker. The pod image is the
published config-baked `dev-sandbox` image from `infra/oci-images`
(`registry.gitlab.com/konradodwrot/infra/oci-images/dev-sandbox`), pulled and
retagged `sandbox:local`, then loaded into the cluster. Each session pod
mounts a PVC at `/home/ko`, seeded from the image's baked home, so session
state survives pod restart and shutdown. This repo owns only the runtime:
kind/k8s config plus session utils and commands.

## Why It Exists

Claude sessions need an isolated shell carrying the full personal config, one
container per session, without touching the host. The config-baked image is
built and published by `infra/oci-images` (public configs, secrets skipped),
so this repo pulls a ready image instead of building one; kind gives cheap
named, persistent, explicitly deleted session pods.

## Goals

- One command from image to shell: pull, cluster up, load, session exec.
- No image building here: the published dev-sandbox image is the pod image.
- Full personal config inside the pod: zsh, che, claude state, same as host cli/linux.
- Persistent named sessions: home survives pod restart, deleted only explicitly.
- Offline-friendly: image loaded into the cluster, pods run `imagePullPolicy: Never`, no pull secrets.
