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

${0:A:h}/bootstrap.zsh

typeset target=${SESSION-}

if [[ -z $target ]] {
  typeset candidates
  if (( include_stopped )) {
    candidates=$(fn-sandbox-sessions)
  } else {
    candidates=$(fn-sandbox-running-sessions)
  }

  #[why] create, then carry on to the attach below: exec would replace this process and the caller
  #   would be left with a created session they were never dropped into
  if [[ -z $candidates ]] {
    print -r -- "${0:t}: no session; creating one"
    target=$(SESSION= ${0:A:h}/session-create.zsh | tee /dev/stderr | sed -n 's/.*session \(.*\) ready/\1/p')
    [[ -n $target ]] || fn-exit-with 1 "${0:t}: session-create produced no session"
  } else {
    target=$(fn-sandbox-pick $candidates) \
      || fn-exit-with 1 "${0:t}: no session picked"
  }
}

fn-sandbox-exists $target \
  || fn-exit-with 1 "${0:t}: session $target does not exist; use session-create"

if [[ $($SANDBOX_KC get statefulset $target -o jsonpath='{.spec.replicas}') == 0 ]] {
  print -r -- "${0:t}: session $target is stopped; starting it"
  $SANDBOX_KC scale statefulset/$target --replicas=1 >/dev/null
}

$SANDBOX_KC rollout status statefulset/$target --timeout=900s >/dev/null

#[why] kubectl exec carries no TERM, so tmux cannot tell the client is utf8 capable and degrades
#   every multibyte glyph: accents become underscores and box drawing becomes solid blocks. -u
#   asserts utf8 rather than leaving tmux to guess, and TERM travels so colours and keys work too
#[why] the base image carries kitty-terminfo and ncurses-term so the host's own TERM travels intact,
#   which is what keeps the session's capabilities identical to the terminal driving it. the probe
#   stays for the terminal nobody packaged: tmux exits with "missing or unsuitable terminal" rather
#   than starting, and a lesser TERM beats no session at all
typeset term=${TERM:-xterm-256color}
$SANDBOX_KC exec ${target}-0 -c sandbox -- infocmp $term >/dev/null 2>&1 \
  || term=xterm-256color

exec $SANDBOX_KC exec -it ${target}-0 -c sandbox -- \
  env TERM=$term LANG=${LANG:-C.UTF-8} \
  tmux -u new-session -A -s main
##[<] 🤖🤖
