##[>] 🤖🤖
#[what] Project's Makefile
SHELL := zsh
.SHELLFLAGS := -c
export PATH := $(CURDIR)/ci/zsh/scripts:$(PATH)

WRAPPERS :=
COMMANDS := render-templates run-repo-ci-prepare-hooks run-repo-ci-precommit-all run-image-build run-cluster-up run-cluster-down run-image-load run-session run-session-stop run-session-rm run-session-ls

.PHONY: $(WRAPPERS) $(COMMANDS)

##[>] Environment Variables [genai-include]
#[what] local configs checkout baked into the image (docker build context), unset -> sibling ../configs
#[vals] path
export CONFIGS_DIR
#[what] in-image path the configs checkout bakes to, unset -> /home/ko/projects/gitlab/<configs parent dir>/configs
#[vals] path
export CONFIGS_BAKE_DIR
#[what] session name (pod + pvc); required by stop/rm, unset on run-session -> s-<datetime>
#[vals] name
export SESSION
##[<] Environment Variables

##[>] Docs [genai-include]
#[what] render *.ontoRepo.tpl onto the repo (.env, makefile.agents.md, repo-structure.md, CLAUDE.md, AGENTS.md, README.md)
render-templates:
	@che render-templates --profile=ontoRepo
##[<] Docs

##[>] Sandbox [genai-include]
#[what] build sandbox:local from the local configs checkout (dev-sandbox base + baked configs)
run-image-build:
	@run-image-build.zsh

#[what] create the single-node kind cluster `sandbox` (no-op when up)
run-cluster-up:
	@run-cluster-up.zsh

#[what] delete the kind cluster `sandbox` (sessions and PVCs go with it)
run-cluster-down:
	@run-cluster-down.zsh

#[what] load sandbox:local into the kind cluster
run-image-load:
	@run-image-load.zsh

#[what] create-or-reattach the SESSION pod (PVC-backed /home/ko) and exec a login zsh; exit leaves it running
run-session:
	@run-session.zsh

#[what] delete the SESSION pod, keep its PVC (home survives)
run-session-stop:
	@run-session-stop.zsh

#[what] delete the SESSION pod and its PVC
run-session-rm:
	@run-session-rm.zsh

#[what] list session pods and PVCs
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
