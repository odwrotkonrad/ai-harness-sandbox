##[>] 🤖🤖
#[what] Project's Makefile
SHELL := zsh
.SHELLFLAGS := -c
export PATH := $(CURDIR)/ci/zsh/scripts:$(PATH)

WRAPPERS := run-all run-all-build run-all-scratch
COMMANDS := render-templates run-repo-ci-prepare-hooks run-repo-ci-precommit-all run-image-pull run-image-build run-prune run-cluster-up run-cluster-down run-cilium-up run-netpol-up run-image-load run-otelcol-up run-session run-session-stop run-session-rm run-session-ls

.PHONY: $(WRAPPERS) $(COMMANDS)

##[>] Environment Variables [genai-include]
#[what] dev-sandbox image tag to pull, unset -> latest
#[vals] tag
export DEV_SANDBOX_TAG
#[what] oci-images checkout the local image build runs in, unset -> sibling ../infra/oci-images
#[vals] path
export OCI_IMAGES_DIR
#[what] session name (pod + pvc); required by stop/rm, unset on run-session -> s-<datetime>
#[vals] name
export SESSION
##[<] Environment Variables

##[>] Docs [genai-include]
#[what] render *.ontoRepo.tpl onto the repo (.env, makefile.agents.md, repo-structure.md, CLAUDE.md, AGENTS.md, README.md)
render-templates:
	@che render-templates
##[<] Docs

##[>] Wrappers [genai-include]
#[what] full flow from the published image: pull, cluster up, cilium + egress policy, load, open a session shell
run-all: run-image-pull run-cluster-up run-cilium-up run-netpol-up run-image-load run-otelcol-up run-session

#[what] full flow from local builds: build ci-linux + dev-sandbox in oci-images, cluster up, cilium + egress policy, load, open a session shell
run-all-build: run-image-build run-cluster-up run-cilium-up run-netpol-up run-image-load run-otelcol-up run-session

#[what] run-all-build from scratch: delete the cluster and prune local images first
run-all-scratch: run-prune run-all-build
##[<] Wrappers

##[>] Sandbox [genai-include]
#[what] pull the published dev-sandbox image (DEV_SANDBOX_TAG) and retag it sandbox:local
run-image-pull:
	@run-image-pull.zsh

#[what] build ci-linux + dev-sandbox locally (make in OCI_IMAGES_DIR) and retag sandbox:local
run-image-build:
	@run-image-build.zsh

#[what] delete the kind cluster and prune the local sandbox images (sandbox/dev-sandbox/ci-linux :local, dangling, build cache)
run-prune:
	@run-prune.zsh

#[what] create the single-node kind cluster `sandbox` (no-op when up)
run-cluster-up:
	@run-cluster-up.zsh

#[what] delete the kind cluster `sandbox` (sessions and PVCs go with it)
run-cluster-down:
	@run-cluster-down.zsh

#[what] install cilium as the CNI with hubble flow metrics (openmetrics :9965), wait ready (no-op when already ok); needs the cilium CLI on PATH
run-cilium-up:
	@run-cilium-up.zsh

#[what] apply the default-deny + FQDN allowlist egress policy (ci/k8s/netpol.yml) to the session pods
run-netpol-up:
	@run-netpol-up.zsh

#[what] load sandbox:local into the kind cluster
run-image-load:
	@run-image-load.zsh

#[what] deploy the in-cluster otel collector (forwards session telemetry to the host otelcol) and wait for rollout
run-otelcol-up:
	@run-otelcol-up.zsh

#[what] create-or-reattach the SESSION pod (overlay home diff on the shared PVC) and exec a login zsh; exit leaves it running
run-session:
	@run-session.zsh

#[what] delete the SESSION pod, keep its home diff (session survives)
run-session-stop:
	@run-session-stop.zsh

#[what] delete the SESSION pod and its home diff
run-session-rm:
	@run-session-rm.zsh

#[what] list session pods and home diffs
run-session-ls:
	@run-session-ls.zsh
##[<] Sandbox

##[>] CI [genai-include]
#[what] install lefthook git hooks
run-repo-ci-prepare-hooks:
	@lefthook install --force

#[what] run pre-commit hooks over all files (not just staged)
run-repo-ci-precommit-all: run-repo-ci-prepare-hooks
	@lefthook run pre-commit --all-files --force
##[<] CI
##[<] 🤖🤖
