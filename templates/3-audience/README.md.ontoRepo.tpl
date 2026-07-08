# sandbox

Local claude session sandbox.

{{ renderMarkdown "assets/docs-agents/purpose.md" "normalize-headings" }}

## Layout

- `ci/dev-sandbox/Dockerfile` — published toolchain base `registry.gitlab.com/konradodwrot/sandbox/dev-sandbox` (multi-arch arm64 + amd64: go, che, render-tpl, lefthook, yq, zsh), built by CI, pins in `ci/tool-versions.env`.
- `ci/Dockerfile` — final `sandbox:local` image: `FROM dev-sandbox`, bakes the local `configs` checkout via che `run-sync-full` (cli/linux profile, secrets skipped).
- `ci/kind.yml` — two-node kind cluster config (control-plane + worker), cluster name `sandbox`; session pods run on the worker.
- `ci/zsh/scripts/` — zsh wrappers behind the Makefile targets.

## Use

```sh
$ make run-image-build run-cluster-up run-image-load
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
