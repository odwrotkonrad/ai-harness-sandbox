# sandbox

Local claude session sandbox.

{{ renderMarkdown "assets/docs-agents/purpose.md" "normalize-headings" }}

## Layout

- `ci/k8s/kind.yml` — two-node kind cluster config (control-plane + worker), cluster name `sandbox`; session pods run on the worker.
- `ci/k8s/session.yml` — session pod + shared home PVC manifest, `${SESSION}` env-substituted at apply time.
- `ci/zsh/scripts/` — zsh wrappers behind the Makefile targets.

The pod image is `registry.gitlab.com/konradodwrot/infra/oci-images/dev-sandbox`
(config-baked, no secrets; amd64 on bare tags, arm64 with an `-arm64` suffix),
built and published by `infra/oci-images`. `run-image-pull` pulls it
(`DEV_SANDBOX_TAG`, default `latest`, arch suffix auto-appended on arm64 hosts)
and retags it `sandbox:local`; `run-image-load` loads that into the
cluster so pods run with `imagePullPolicy: Never`.

## Use

```sh
$ make run-all
$ make run-session
$ make run-session SESSION=s-mytopic
$ make run-session-ls
$ make run-session-stop SESSION=s-mytopic
$ make run-session-rm SESSION=s-mytopic
$ make run-cluster-down
```

A session is a named pod whose `/home/ko` is an overlayfs: the image's baked
home is the shared read-only base, the session's writable diff lives in its
own subdir on the one shared `sandbox-home` PVC (no per-session copy of the
base). Exiting the shell leaves the pod running; `run-session` with the same
`SESSION` reattaches. `run-session-stop` deletes the pod but keeps the diff
(session survives); `run-session-rm` deletes both.

## License

MIT — see [LICENSE](LICENSE).
