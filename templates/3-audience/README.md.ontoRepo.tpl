# sandbox

Local claude session sandbox.

{{ renderMarkdown "assets/docs-agents/purpose.md" "normalize-headings" }}

## Layout

- `ci/kind.yml` — two-node kind cluster config (control-plane + worker), cluster name `sandbox`; session pods run on the worker.
- `ci/zsh/scripts/` — zsh wrappers behind the Makefile targets.

The pod image is `registry.gitlab.com/konradodwrot/infra/oci-images/dev-sandbox`
(config-baked, no secrets; amd64 on bare tags, arm64 with an `-arm64` suffix),
built and published by `infra/oci-images`. `run-image-pull` pulls it
(`DEV_SANDBOX_TAG`, default `latest`, arch suffix auto-appended on arm64 hosts)
and retags it `sandbox:local`; `run-image-load` loads that into the
cluster so pods run with `imagePullPolicy: Never`.

## Use

```sh
$ make run-image-pull run-cluster-up run-image-load
$ make run-session
$ make run-session SESSION=s-mytopic
$ make run-session-ls
$ make run-session-stop SESSION=s-mytopic
$ make run-session-rm SESSION=s-mytopic
$ make run-cluster-down
```

A session is a named pod plus a PVC mounted at `/home/ko`, seeded from the
image's baked home on first start. Exiting the shell leaves the pod running;
`run-session` with the same `SESSION` reattaches. `run-session-stop` deletes
the pod but keeps the PVC (home survives); `run-session-rm` deletes both.

## License

MIT — see [LICENSE](LICENSE).
