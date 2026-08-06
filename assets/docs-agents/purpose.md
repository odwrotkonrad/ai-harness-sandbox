# Purpose

## What It Is

Local claude session sandbox: a two-node kind cluster (`sandbox`, one
control-plane node for the management plane, one worker node for the data
plane) running persistent per-session pods on the worker. This repo owns the
sandbox image and its config composition: `ci/docker/` bakes a
`debian:bookworm-slim` base with che, a shallow clone of the public `configs`
repo at its standard workspace path (`~/projects/gitlab/konradodwrot/configs`,
kept synced as a normal workspace repo from then on), and a `sandbox-build`
profile (defined in
`ci/docker/che.yml`, composing configs tool profiles from that clone: zsh,
git, claude, codex, gcloud, glab, ssh config; secret-free by construction),
CI publishes it per-arch to this project's private registry
(`registry.gitlab.com/konradodwrot-restricted/sandbox/sandbox`, amd64 bare
tags, arm64 `-arm64` suffixed). The host pulls the newest published image by
default (`make`, bare; needs `docker login`; `session-create` re-checks and
refreshes a stale pull on every run) or builds it locally for sandbox dev
(`make all-build`), tags it `sandbox:local`, then pushes it to a host-local
`registry:2`
(`kind-registry`, `127.0.0.1:5001`) that a containerd mirror patch maps to
`kind-registry:5000` in-network, so nodes pull it and iterative builds transfer
only changed layers by digest instead of re-loading the whole image tar. At pod
creation, `session-create` refreshes the configs checkout (skipped when dirty)
and runs the `sandbox-runtime` profile in the pod: ADC auth check, ssh keypair
rendered from GCP Secrets Manager, workspace clone + repo index — every secret
enters at runtime, none is baked. Session
home is an
overlayfs: the image's baked `/home/ko` is the shared read-only base, one
shared PVC keeps each session's writable diff, so session state survives pod
restart and shutdown without copying the base per session. Cilium is the CNI:
session egress runs default-deny with a `CiliumNetworkPolicy` `toFQDNs`
allowlist, so a pod reaches only allowlisted domains over HTTPS and everything
else (raw IPs, unknown domains, plain HTTP on port 80) drops in-kernel. Hubble
exports flow/drop metrics that ride the existing sandbox→host otelcol pipe into
the host Prometheus/Grafana, so egress (allowed vs denied, top-denied FQDN,
per-source) is queryable there.

## Why It Exists

Claude sessions need an isolated shell carrying the personal config, one
container per session, without touching the host. The image must bake no
secrets, so the config splits into a secret-free `sandbox-build` bake and a
`sandbox-runtime` pod-creation profile, both composed in this repo from
`configs` tool profiles; owning image and composition here keeps the whole
sandbox lifecycle (bake, publish, cluster, sessions) in the one repo that also
holds its restricted identity. kind gives cheap named, persistent, explicitly
deleted session pods.

## Goals

- One repo owns the sandbox end to end: profile composition, image bake, registry publish, cluster, sessions.
- One command from image to shell: build or pull, cluster up, load, session exec.
- No secrets baked: the image bakes the secret-free `sandbox-build` profile; `sandbox-runtime` injects identity at pod creation (ADC check, ssh keys, workspace clone), all via the injected GCP SA key.
- Both arches published from CI: amd64 bare tags, arm64 `-arm64` suffixed; rebuilt on configs main and che releases via cross-project triggers.
- Persistent named sessions: home diff survives pod restart, deleted only explicitly.
- Space-efficient sessions: one shared home base (image layer), per-session overlay diffs on one PVC.
- Offline-friendly: image pushed to a host-local registry, nodes pull it in-network via the containerd mirror (`imagePullPolicy: Always`, host-local so no external network), no pull secrets.
- Egress control: Cilium CNI, default-deny + FQDN allowlist, HTTPS only (plain HTTP denied).
- Egress visible: Hubble flow/drop metrics ride the existing otelcol pipe into host Prometheus/Grafana.
