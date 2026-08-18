#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
typeset repo_root=$(git -C ${0:A:h} rev-parse --show-toplevel)
source $repo_root/ci/zsh/lib/session-lib.zsh

typeset -i include_stopped=0
[[ ${1-} == --stopped || ${SESSION_STOPPED-} == 1 ]] && include_stopped=1

fn-sandbox-require ${0:t}

#[why] a pod re-pulls on every start, so its running image is always current: what goes stale is the
#   home, seeded once and never again. HOME compares the digest recorded at seeding against the
#   image a new session would get, which is the difference that decides whether a rebuild reached it
typeset -a rows=( 'SESSION STATE DISK HOME' )
typeset name replicas state disk seeded home
typeset current=$(fn-sandbox-image-digest)

for name in ${(f)"$(fn-sandbox-sessions)"}; do
  replicas=$($SANDBOX_KC get statefulset $name -o jsonpath='{.spec.replicas}' 2>/dev/null)
  if [[ $replicas == 0 ]] {
    (( include_stopped )) || continue
    state=stopped
  } else {
    state=running
  }

  disk=$($SANDBOX_KC get pvc home-${name}-0 -o jsonpath='{.status.capacity.storage}' 2>/dev/null)

  seeded=$($SANDBOX_KC get statefulset $name \
    -o jsonpath='{.spec.template.metadata.annotations.sandbox/image-digest}' 2>/dev/null)
  if [[ -z $current || -z $seeded ]] {
    home=unknown
  } elif [[ $seeded == $current ]] {
    home=current
  } else {
    home=stale
  }

  rows+=( "$name ${state} ${disk:-unknown} ${home}" )
done

(( $#rows > 1 )) || { print -r -- 'no sessions'; return 0 }
print -rl -- $rows | column -t
if [[ $rows == *stale* ]] {
  print -r -- ''
  print -r -- 'stale: the home predates the current config image; only a new session picks the rebuild up'
}
##[<] 🤖🤖
