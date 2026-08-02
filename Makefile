##[>] 🤖🤖
#[what] Project's Makefile
SHELL := zsh
.SHELLFLAGS := -c
export PATH := $(CURDIR)/ci/zsh/scripts:$(PATH)

WRAPPERS := all all-build all-scratch
COMMANDS := render-templates repo-ci-prepare-hooks repo-ci-precommit-all image-pull image-build prune registry-up cluster-up cluster-down cilium-up netpol-up image-load otelcol-up session-create session-attach session-stop session-rm session-ls

.PHONY: $(WRAPPERS) $(COMMANDS)

#[why] default to the local-build flow: bare `make` never touches the GitLab registry (all's image-pull does); remote pull stays an explicit `make all`
.DEFAULT_GOAL := all-build

##[>] Environment Variables [genai-include]
#[what] published sandbox image tag to pull, unset -> latest
#[vals] tag
export SANDBOX_TAG
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
#[what] remote flow: pull the published sandbox image from this project's GitLab registry (private: needs a prior `docker login registry.gitlab.com`), registry up, cluster up, cilium + egress policy, push to local registry, open a session shell
all: image-pull registry-up cluster-up cilium-up netpol-up image-load otelcol-up session-create

#[what] default local flow (bare `make`): build the sandbox image from ci/docker/Dockerfile, registry up, cluster up, cilium + egress policy, push to local registry, open a session shell; no GitLab registry
all-build: image-build registry-up cluster-up cilium-up netpol-up image-load otelcol-up session-create

#[what] all-build from scratch: delete the cluster and prune local images first
all-scratch: prune all-build
##[<] Wrappers

##[>] Sandbox [genai-include]
#[what] pull the published sandbox image (SANDBOX_TAG) from the private project registry and retag it sandbox:local
image-pull:
	@image-pull.zsh

#[what] build sandbox:local from ci/docker/Dockerfile (secret-free sandbox-build bake of configs main)
image-build:
	@image-build.zsh

#[what] delete the kind cluster and prune the local sandbox image (sandbox:local, dangling, build cache)
prune:
	@prune.zsh

#[what] start the host-local registry (kind-registry, 127.0.0.1:5001) and join it to the kind network (no-op when running); must run before cluster-up so the containerd mirror patch resolves
registry-up:
	@registry-up.zsh

#[what] create the single-node kind cluster `sandbox` (no-op when up)
cluster-up:
	@cluster-up.zsh

#[what] delete the kind cluster `sandbox` (sessions and PVCs go with it)
cluster-down:
	@cluster-down.zsh

#[what] install cilium as the CNI with hubble flow metrics (openmetrics :9965), wait ready (no-op when already ok); needs the cilium CLI on PATH
cilium-up:
	@cilium-up.zsh

#[what] apply the default-deny + FQDN allowlist egress policy (ci/k8s/netpol.yml) to the session pods
netpol-up:
	@netpol-up.zsh

#[what] tag sandbox:local as localhost:5001/sandbox:local and push it to the host registry (only changed layers upload); session pods pull it via the containerd mirror
image-load:
	@image-load.zsh

#[what] deploy the in-cluster otel collector (forwards session telemetry to the host otelcol) and wait for rollout
otelcol-up:
	@otelcol-up.zsh

#[what] create a new SESSION pod (overlay home diff on the shared PVC), run the sandbox-runtime profile (auth check, ssh keys, workspace clone + index), and exec a login zsh; exit leaves it running. SESSION unset -> s-<datetime>
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
repo-ci-prepare-hooks:
	@lefthook install --force

#[what] run pre-commit hooks over all files (not just staged)
repo-ci-precommit-all: repo-ci-prepare-hooks
	@lefthook run pre-commit --all-files --force
##[<] CI
##[<] 🤖🤖
