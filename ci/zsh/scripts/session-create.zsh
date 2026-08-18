#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
typeset repo_root=$(git -C ${0:A:h} rev-parse --show-toplevel)
source $repo_root/ci/zsh/lib/session-lib.zsh

fn-sandbox-require ${0:t}
(( $+commands[yq] )) || fn-exit-with 1 "${0:t}: yq not found"

${0:A:h}/bootstrap.zsh

#[why] the bootstrap applies the policy, so reaching here without it means cilium never took it:
#   refuse rather than create a session whose egress is unenforced
$SANDBOX_KC get ciliumnetworkpolicy sandbox-default-deny >/dev/null 2>&1 \
  || fn-exit-with 1 "${0:t}: the egress policy is absent after bootstrap; refusing to create an unconfined session"

export SESSION=${SESSION:-$(fn-sandbox-new-name ${0:t})}

fn-sandbox-exists $SESSION \
  && fn-exit-with 1 "${0:t}: session $SESSION already exists; use session-attach"

export SANDBOX_IMAGE_DIGEST=$(fn-sandbox-image-digest)

yq '(.. | select(tag == "!!str")) |= envsubst' $repo_root/ci/k8s/session.yml | $SANDBOX_KC apply -f -
$SANDBOX_KC rollout status statefulset/$SESSION --timeout=900s

print -r -- "${0:t}: session $SESSION ready"
##[<] 🤖🤖
