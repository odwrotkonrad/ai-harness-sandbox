#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
typeset repo_root=$(git -C ${0:A:h} rev-parse --show-toplevel)
source $repo_root/ci/zsh/lib/session-lib.zsh

fn-sandbox-require ${0:t}

${0:A:h}/image-build-config.zsh

typeset name
for name in ${(f)"$(fn-sandbox-running-sessions)"}; do
  print -r -- "${0:t}: recreating $name on the rebuilt image"
  $SANDBOX_KC rollout restart statefulset/$name >/dev/null
done

for name in ${(f)"$(fn-sandbox-running-sessions)"}; do
  $SANDBOX_KC rollout status statefulset/$name --timeout=900s
done

print -r -- "${0:t}: configuration image rebuilt; new sessions boot from it"
print -r -- "${0:t}: existing sessions keep the \$HOME they were seeded with"
##[<] 🤖🤖
