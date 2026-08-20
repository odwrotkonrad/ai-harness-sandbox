##[>] 🤖🤖
SHELL := zsh
.SHELLFLAGS := -c
export PATH := $(CURDIR)/ci/zsh/scripts:$(PATH)

WRAPPERS := repo-prepare-dev-env all all-scratch
COMMANDS := render-templates repo-render-env repo-ci-prepare-hooks repo-ci-precommit-all bootstrap machine-up image-build-base image-build-installs image-build-config prune registry-up cluster-up cluster-down cilium-up netpol-up egress-denied session-create session-attach session-stop session-rm session-ls session-rename session-update-config test-e2e

.PHONY: $(WRAPPERS) $(COMMANDS)

.DEFAULT_GOAL := all

##[>] Dev Environment [genai-include]
#[why] render precedes hooks: the docsgen pre-commit hook runs render-templates and fails on drift,
#   so a fresh clone whose generated files were never rendered would fail its first commit
#[what] make a fresh clone a working checkout: generated docs, git hooks
repo-prepare-dev-env: repo-render-env render-templates repo-ci-prepare-hooks
##[<] Dev Environment

##[>] Environment Variables [genai-include]
#[what] session name (statefulset + pvc); unset on session-create -> a random mnemonic, unset on session-attach/stop/rm -> picked
#[vals] name
export SESSION
#[what] new session name for session-rename
#[vals] name
export SESSION_NEW
#[what] include stopped sessions in session-attach and session-ls
#[vals] 1
export SESSION_STOPPED
#[what] egress-denied: how many recent flows to scan
#[vals] count
export EGRESS_LAST
#[what] test-e2e: prune the cluster and all three image layers first, proving a bootstrap from nothing (~40 min rebuild); unset -> reuse what is built
#[vals] 1
export E2E_SCRATCH
#[what] test-e2e: delete the cluster when the run passes; unset -> keep it, so the next run skips the rebuild
#[vals] 1
export E2E_TEARDOWN
##[<] Environment Variables

##[>] Docs [genai-include]
#[what] render *.ontoRepo.tpl onto the repo (makefile.agents.md, repo-structure.md, CLAUDE.md, AGENTS.md, README.md)
render-templates:
	@che render-templates --profiles=ontoRepo

#[what] render .env.tpl to .env: upstream refs and CI variables via glab, secrets via op
repo-render-env:
	@CHE_ENV_UNSET=empty che render-templates --profiles=envSeed
##[<] Docs

##[>] Wrappers [genai-include]
#[what] default flow (bare `make`): attach to a session, bringing up whatever it needs first (machine, registry, cluster, cilium, egress policy, any missing image layer) and creating a session when none exists
all: session-attach

#[what] all from scratch: delete the cluster, prune the local images, rebuild all three layers, then bring everything up
all-scratch: prune image-build-base image-build-installs image-build-config all
##[<] Wrappers

##[>] Sandbox [genai-include]
#[what] bring up everything a session needs and nothing more: podman machine, registry, cluster, cilium, egress policy, plus any image layer that is missing; every step a no-op once it holds. the session verbs run this themselves
bootstrap:
	@bootstrap.zsh

#[what] create/start the rootful podman machine sizing it for the cluster (no-op when running); rootful is required for cilium's ebpf datapath
machine-up:
	@machine-up.zsh

#[what] build the base layer (debian, zsh, the session user, che) and push it to the local registry; changes rarely
image-build-base:
	@image-build-base.zsh

#[what] build the installs layer (che install-packages only) on the base and push it; changes rarely
image-build-installs:
	@image-build-installs.zsh

#[what] build the config layer (every che op but install-packages, plus claude and gcp credentials) on the installs and push it; changes often
image-build-config:
	@image-build-config.zsh

#[what] delete the kind cluster and prune the local sandbox images
prune:
	@prune.zsh

#[what] start the host-local registry (kind-registry, 127.0.0.1:5001) and join it to the kind network (no-op when running); must run before cluster-up so the containerd mirror patch resolves
registry-up:
	@registry-up.zsh

#[what] create the two-node kind cluster `sandbox` on podman (control-plane + session worker) and apply the namespace quota and limit range (no-op when up)
cluster-up:
	@cluster-up.zsh

#[what] delete the kind cluster `sandbox` (sessions and PVCs go with it)
cluster-down:
	@cluster-down.zsh

#[what] install cilium as the CNI with hubble policy verdicts, wait ready (no-op when already ok); needs the cilium CLI on PATH
cilium-up:
	@cilium-up.zsh

#[what] apply the default-deny + FQDN allowlist + host-deny egress policy (ci/k8s/netpol.yml); refuses when cilium is not ready
netpol-up:
	@netpol-up.zsh

#[what] report what the egress policy refused: denied dns names (counted, search-domain noise filtered) and denied connections, so a missing allowlist entry is one command away
egress-denied:
	@egress-denied.zsh

#[what] create a new session (one StatefulSet, replicas=1, its own PVC at /home/ko), bootstrapping the cluster and any missing image layer first; SESSION unset -> a random mnemonic
session-create:
	@session-create.zsh

#[what] attach to a session, bootstrapping the cluster and any missing image layer first: none -> create one, one -> attach, several -> pick; SESSION_STOPPED=1 includes stopped sessions, starting the picked one
session-attach:
	@session-attach.zsh

#[what] scale a session to 0, releasing cpu and memory while its PVC keeps the data; SESSION unset -> pick
session-stop:
	@session-stop.zsh

#[what] delete a session's StatefulSet and its PVC (the PVC outlives the StatefulSet, so it is deleted explicitly); SESSION unset -> pick
session-rm:
	@session-rm.zsh

#[what] list sessions with their state and volume size; SESSION_STOPPED=1 includes stopped ones
session-ls:
	@session-ls.zsh

#[what] rename a session, keeping its volume; refuses a collision (session-rename SESSION=<from> SESSION_NEW=<to>)
session-rename:
	@session-rename.zsh $(SESSION) $(SESSION_NEW)

#[what] rebuild the config layer and recreate running sessions' pods on it; a session keeps the $HOME it was seeded with
session-update-config:
	@session-update-config.zsh
##[<] Sandbox

##[>] CI [genai-include]
#[what] run the host e2e test: cluster bootstrap, all three layer builds, the session targets, a config update; reuses the built cluster and images and keeps them (E2E_SCRATCH=1 / E2E_TEARDOWN=1 to opt into either end)
test-e2e:
	@ci/zsh/tests/e2e.zsh

#[what] install lefthook git hooks
repo-ci-prepare-hooks:
	@lefthook install --force

#[what] run pre-commit hooks over all files (not just staged)
repo-ci-precommit-all: repo-ci-prepare-hooks
	@lefthook run pre-commit --all-files --force
##[<] CI
##[<] 🤖🤖
