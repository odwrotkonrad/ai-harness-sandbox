# Purpose

## What It Is

Local claude session sandbox: a two-node kind cluster (`sandbox`, one
control-plane node for the management plane, one worker node for the data
plane) running persistent per-session pods on the worker from a locally built
`sandbox:local` image. Owns
the published `dev-sandbox` toolchain base (debian bookworm, multi-arch
arm64 + amd64: go, che, render-tpl, lefthook, yq, zsh), built by CI to this
project's container registry. The final image builds FROM that base locally,
baking the local `configs` checkout at build time (che `run-sync-full`,
cli/linux profile, secrets skipped). Each session pod mounts a PVC at
`/home/ko`, seeded from the image's baked home, so session state survives pod
restart and shutdown.

## Why It Exists

Claude sessions need an isolated shell carrying the full personal config, one
container per session, without touching the host. Building the config-baked
image locally keeps secrets out of registries and reuses the exact configs
checkout on disk; kind gives cheap named, persistent, explicitly deleted
session pods.

## Goals

- One command from image to shell: build, cluster up, load, session exec.
- One published multi-arch toolchain base; config baking stays local.
- Full personal config inside the pod: zsh, che, claude state, same as host cli/linux.
- Persistent named sessions: home survives pod restart, deleted only explicitly.
- No secrets baked: renders with op:// secret refs are skipped at build time.
