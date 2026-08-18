#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
typeset repo_root=$(git -C ${0:A:h} rev-parse --show-toplevel)
source $repo_root/ci/zsh/lib/session-lib.zsh

fn-sandbox-require ${0:t}

typeset target=${SESSION-}
[[ -n $target ]] || target=$(fn-sandbox-pick "$(fn-sandbox-running-sessions)") \
  || fn-exit-with 1 "${0:t}: no running session to stop"

fn-sandbox-exists $target \
  || fn-exit-with 1 "${0:t}: session $target does not exist"

$SANDBOX_KC scale statefulset/$target --replicas=0 >/dev/null
print -r -- "${0:t}: session $target stopped; its data is kept"
##[<] 🤖🤖
