# Purpose

## What It Is

Local claude session sandbox: a two-node kind cluster (`sandbox`, one
control-plane node for the management plane, one worker node for the data
plane) running persistent per-session pods on the worker. The pod image is the
published config-baked `dev-sandbox` image from `infra/oci-images`
(`registry.gitlab.com/konradodwrot/infra/oci-images/dev-sandbox`), pulled and
retagged `sandbox:local`, then pushed to a host-local `registry:2`
(`kind-registry`, `127.0.0.1:5001`) that a containerd mirror patch maps to
`kind-registry:5000` in-network, so nodes pull it and iterative builds transfer
only changed layers by digest instead of re-loading the whole image tar. Session
home is an
overlayfs: the image's baked `/home/ko` is the shared read-only base, one
shared PVC keeps each session's writable diff, so session state survives pod
restart and shutdown without copying the base per session. Cilium is the CNI:
session egress runs default-deny with a `CiliumNetworkPolicy` `toFQDNs`
allowlist, so a pod reaches only allowlisted domains over HTTPS and everything
else (raw IPs, unknown domains, plain HTTP on port 80) drops in-kernel. Hubble
exports flow/drop metrics that ride the existing sandbox→host otelcol pipe into
the host Prometheus/Grafana, so egress (allowed vs denied, top-denied FQDN,
per-source) is queryable there. This repo owns only the runtime: kind/k8s config
plus session utils and commands.

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
- Persistent named sessions: home diff survives pod restart, deleted only explicitly.
- Space-efficient sessions: one shared home base (image layer), per-session overlay diffs on one PVC.
- Offline-friendly: image pushed to a host-local registry, nodes pull it in-network via the containerd mirror (`imagePullPolicy: Always`, host-local so no external network), no pull secrets.
- Egress control: Cilium CNI, default-deny + FQDN allowlist, HTTPS only (plain HTTP denied).
- Egress visible: Hubble flow/drop metrics ride the existing otelcol pipe into host Prometheus/Grafana.
