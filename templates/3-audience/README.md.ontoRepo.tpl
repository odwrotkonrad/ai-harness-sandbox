# sandbox

Local claude session sandbox.

{{ renderMarkdown "assets/docs-agents/purpose.md" "normalize-headings" }}

## Layout

- `ci/k8s/kind.yml` — two-node kind cluster config (control-plane + worker), cluster name `sandbox`, `disableDefaultCNI` (Cilium is the CNI); session pods run on the worker.
- `ci/k8s/session.yml` — session pod + shared home PVC manifest, `${SESSION}` env-substituted at apply time.
- `ci/k8s/netpol.yml` — one `CiliumNetworkPolicy` (`sandbox-egress`): default-deny with three egress rules — cluster DNS, in-cluster telemetry, and the FQDN allowlist (443 only).
- `ci/k8s/otelcol.yml` — in-cluster otel collector; forwards session telemetry to the host otelcol and scrapes Hubble flow metrics into the same pipe.
- `ci/zsh/scripts/` — zsh wrappers behind the Makefile targets.

The pod image is `registry.gitlab.com/konradodwrot/infra/sandbox/sandbox`
(config-baked via the `sandbox-build` profile in `ci/docker/che.yml`, no secrets; amd64 on
bare tags, arm64 with an `-arm64` suffix), built from `ci/docker/Dockerfile`
and published by this project's own CI to its private registry. `image-pull`
(the default flow) pulls the published one (`SANDBOX_TAG`, default `latest`,
arch suffix auto-appended on arm64 hosts, needs a prior
`docker login registry.gitlab.com`) and retags it `sandbox:local`;
`image-build` (sandbox dev) builds it locally instead. `session-create`
re-checks the published digest on every run and refreshes a stale or missing
`sandbox:local` (local dev builds are kept); `session-attach` warns when the
pod runs an outdated image. `registry-up` starts a host-local
`registry:2` (`kind-registry`, `127.0.0.1:5001`) and `image-load` tags
`sandbox:local` as `localhost:5001/sandbox:local` and pushes it there. A
containerd mirror patch in `kind.yml` maps `localhost:5001` to
`kind-registry:5000` in-network, so nodes pull from the same registry and
iterative builds transfer only changed layers by digest (no full-image tar
re-load). Pods run with `imagePullPolicy: Always` (the `:local` tag is mutable,
so a rebuild+push must reach the pod); the registry is host-local, so pulls stay
off the external network.

## Use

```sh
$ make
$ make session-create
$ make session-create SESSION=s-mytopic
$ make session-attach
$ make session-attach SESSION=s-mytopic
$ make session-ls
$ make session-stop SESSION=s-mytopic
$ make session-rm SESSION=s-mytopic
$ make cluster-down
```

A session is a named pod whose `/home/ko` is an overlayfs: the image's baked
home is the shared read-only base, the session's writable diff lives in its
own subdir on the one shared `sandbox-home` PVC (no per-session copy of the
base). Exiting the shell leaves the pod running; `session-attach` (no
`SESSION` -> most recent) reattaches. `session-stop` deletes the pod but keeps
the diff (session survives); `session-rm` deletes both.

## Traffic management

Session egress is Cilium-enforced default-deny. `ci/k8s/netpol.yml` holds one
`CiliumNetworkPolicy` (`sandbox-egress`) selecting the session pods
(`app: claude-sandbox`) with three egress rules: cluster DNS (kube-dns, with
resolution snooping so Cilium can match FQDNs), the in-cluster otel collector,
and an allowlist of a fixed set of domains on 443 (TCP) only. Anything not
listed — raw IPs, unknown domains, and all plain HTTP on port 80 — is dropped
in-kernel; there is no port-80 rule anywhere, so HTTP is denied even for
allowlisted domains.

Cilium images pull from quay.io at install time (`cilium-up`), so cluster
bootstrap needs network (it already does, to build or pull the sandbox image).

**Extend the allowlist:** add one `matchName`/`matchPattern` line under
`toFQDNs` in the `sandbox-egress` policy, then `make netpol-up`.

**Observe egress:** Hubble runs with OpenMetrics on (`:9965` on each Cilium
agent). The in-cluster otel collector scrapes those `hubble_*` flow/drop/dns
series and forwards them down the existing pipe to the host otelcol, so they land
in host Prometheus (`hubble_flows_processed_total`, `hubble_drop_total`,
`hubble_dns_queries_total`, labeled by `verdict` and resolved `destination`
FQDN) and are queryable in Grafana Explore. `hubble observe --verdict DROPPED`
gives the same view interactively.

## License

MIT — see [LICENSE](LICENSE).
