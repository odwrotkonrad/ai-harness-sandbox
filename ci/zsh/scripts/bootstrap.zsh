#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
#[why] a session verb must not fail telling the user to run another target: everything a session
#   needs is brought up here, and every step is a no-op once it holds. only the layer builds are
#   skipped when their image already exists, since rebuilding costs tens of minutes and a rebuild
#   is what image-build-* and session-update-config are for

#[why] bringing up what already holds is not news: hold each step's output and print it only when
#   the step fails, so an attach onto a healthy cluster says nothing at all. the layer builds run
#   unwrapped, since those are the minutes-long ones worth watching
fn-quietly() {
  typeset log=$(mktemp)
  if { ! "$@" >$log 2>&1 } {
    print -ru2 -- "${0:t}: $1 failed:"
    cat $log >&2
    rm -f $log
    return 1
  }
  rm -f $log
}

source $(git -C ${0:A:h} rev-parse --show-toplevel)/ci/zsh/lib/cluster-lib.zsh

fn-quietly ${0:A:h}/registry-up.zsh

#[why] creating the cluster and installing cilium take minutes: say so before going quiet, or the
#   silence reads as a hang. once they hold there is nothing to announce
fn-sandbox-cluster-exists || print -r -- 'bringing the cluster up (a few minutes)'
fn-quietly ${0:A:h}/cluster-up.zsh

podman image exists localhost:5001/sandbox-base:local \
  || ${0:A:h}/image-build-base.zsh
podman image exists localhost:5001/sandbox-installs:local \
  || ${0:A:h}/image-build-installs.zsh
podman image exists localhost:5001/sandbox:local \
  || ${0:A:h}/image-build-config.zsh

cilium status --context kind-sandbox --wait=false >/dev/null 2>&1 \
  || print -r -- 'installing cilium (a few minutes)'
fn-quietly ${0:A:h}/cilium-up.zsh
fn-quietly ${0:A:h}/netpol-up.zsh
##[<] 🤖🤖
