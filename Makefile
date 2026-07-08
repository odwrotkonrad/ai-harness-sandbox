##[>] 🤖🤖
#[what] Project's Makefile
SHELL := zsh
.SHELLFLAGS := -c
export PATH := $(CURDIR)/ci/zsh/scripts:$(PATH)

WRAPPERS := run-all
COMMANDS := render-templates run-repo-ci-prepare-hooks run-repo-ci-precommit-all run-image-pull run-cluster-up run-cluster-down run-image-load run-session run-session-stop run-session-rm run-session-ls

.PHONY: $(WRAPPERS) $(COMMANDS)

##[>] Environment Variables [genai-include]
#[what] dev-sandbox image tag to pull, unset -> latest
#[vals] tag
export DEV_SANDBOX_TAG
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
#[what] full flow: pull image, cluster up, load image, open a session shell
run-all: run-image-pull run-cluster-up run-image-load run-session
##[<] Wrappers

##[>] Sandbox [genai-include]
#[what] pull the published dev-sandbox image (DEV_SANDBOX_TAG) and retag it sandbox:local
run-image-pull:
	@run-image-pull.zsh

#[what] create the single-node kind cluster `sandbox` (no-op when up)
run-cluster-up:
	@run-cluster-up.zsh

#[what] delete the kind cluster `sandbox` (sessions and PVCs go with it)
run-cluster-down:
	@run-cluster-down.zsh

#[what] load sandbox:local into the kind cluster
run-image-load:
	@run-image-load.zsh

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
