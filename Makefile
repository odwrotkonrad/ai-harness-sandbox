##[>] 🤖🤖
#[what] Project's Makefile
SHELL := zsh
.SHELLFLAGS := -c
export PATH := $(CURDIR)/ci/zsh/scripts:$(PATH)

WRAPPERS := run-all run-all-build run-all-scratch
COMMANDS := render-templates run-repo-ci-prepare-hooks run-repo-ci-precommit-all run-image-pull run-image-build run-prune run-registry-up run-cluster-up run-cluster-down run-cilium-up run-netpol-up run-image-load run-otelcol-up session-create session-attach session-stop session-rm session-ls

.PHONY: $(WRAPPERS) $(COMMANDS)

#[why] default to the local-build flow: bare `make` never touches the GitLab registry (run-all's run-image-pull does); remote pull stays an explicit `make run-all`
.DEFAULT_GOAL := run-all-build

##[>] Environment Variables [genai-include]
#[what] dev-sandbox image tag to pull, unset -> latest
#[vals] tag
export DEV_SANDBOX_TAG
#[what] oci-images checkout the local image build runs in, unset -> sibling ../infra/oci-images, else ../../konradodwrot/infra/oci-images
#[vals] path
export OCI_IMAGES_DIR
#[what] session name (pod + pvc); required by stop/rm, unset on session-create -> s-<datetime>, unset on session-attach -> most recent
#[vals] name
export SESSION
##[<] Environment Variables

##[>] Docs [genai-include]
#[what] render *.ontoRepo.tpl onto the repo (.env, makefile.agents.md, repo-structure.md, CLAUDE.md, AGENTS.md, README.md)
render-templates:
	@che render-templates
##[<] Docs

##[>] Wrappers [genai-include]
#[what] remote flow: pull the published dev-sandbox image from the GitLab registry, registry up, cluster up, cilium + egress policy, push to local registry, open a session shell
run-all: run-image-pull run-registry-up run-cluster-up run-cilium-up run-netpol-up run-image-load run-otelcol-up session-create

#[what] default local flow (bare `make`): build ci-linux + dev-sandbox in oci-images, registry up, cluster up, cilium + egress policy, push to local registry, open a session shell; no GitLab registry
run-all-build: run-image-build run-registry-up run-cluster-up run-cilium-up run-netpol-up run-image-load run-otelcol-up session-create

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

#[what] start the host-local registry (kind-registry, 127.0.0.1:5001) and join it to the kind network (no-op when running); must run before run-cluster-up so the containerd mirror patch resolves
run-registry-up:
	@run-registry-up.zsh

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

#[what] tag sandbox:local as localhost:5001/sandbox:local and push it to the host registry (only changed layers upload); session pods pull it via the containerd mirror
run-image-load:
	@run-image-load.zsh

#[what] deploy the in-cluster otel collector (forwards session telemetry to the host otelcol) and wait for rollout
run-otelcol-up:
	@run-otelcol-up.zsh

#[what] create a new SESSION pod (overlay home diff on the shared PVC), render its GCP secrets, and exec a login zsh; exit leaves it running. SESSION unset -> s-<datetime>
session-create:
	@session-create.zsh

#[what] attach a login zsh to an existing session; SESSION unset -> most recent running session
session-attach:
	@session-attach.zsh

#[what] delete the SESSION pod, keep its home diff (session survives)
session-stop:
	@session-stop.zsh

#[what] delete the SESSION pod and its home diff
session-rm:
	@session-rm.zsh

#[what] list running sessions and all home diffs (running + stopped)
session-ls:
	@session-ls.zsh
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
