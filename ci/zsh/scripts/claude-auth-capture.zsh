#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
typeset dest=${1:?dest path required}

:>$dest
chmod 600 $dest

#[why] claude code keeps one keychain entry per account, suffixed with an account hash, and leaves
#   the legacy unsuffixed entry behind when it migrates. reading the bare name picks up a token that
#   expired months ago, so every candidate is checked and the first unexpired one wins
fn-claude-token-valid() {
  python3 -c '
import json, sys, time
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
o = d.get("claudeAiOauth", d)
exp = o.get("expiresAt")
sys.exit(0 if exp and exp / 1000 > time.time() else 1)
' <$1
}

fn-capture-from-keychain() {
  typeset svc
  for svc in ${(f)"$(security dump-keychain 2>/dev/null | sed -n 's/.*"svce"<blob>="\(Claude Code-credentials[^"]*\)".*/\1/p' | sort -u)"}; do
    [[ -n $svc ]] || continue
    security find-generic-password -s $svc -w >$dest 2>/dev/null || continue
    if { fn-claude-token-valid $dest } {
      print -r -- "${0:t}: captured the host's claude credential unattended ($svc)"
      return 0
    }
  done
  :>$dest
  return 1
}

#[why] the same CLAUDE_CONFIG_DIR the profile sets, falling back to claude's own default: reading
#   only ~/.claude would miss the host's credential wherever that variable points elsewhere
typeset -a candidates=(
  ${CLAUDE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/claude}/.credentials.json
  $HOME/.claude/.credentials.json
)

typeset candidate
for candidate in $candidates; do
  [[ -s $candidate ]] || continue
  cat $candidate >$dest
  fn-claude-token-valid $dest && break
  :>$dest
done

if [[ ! -s $dest ]] {
  fn-capture-from-keychain || :
}

if [[ -s $dest ]] {
  return 0
}

(( $+commands[podman] )) || fn-exit-with 1 "${0:t}: podman not found"

print -r -- "${0:t}: no unexpired claude credential on the host; starting a throwaway login container"
print -r -- "${0:t}: log in once, then exit the container to capture the credential"

typeset ctr=sandbox-claude-login-$$
trap 'podman rm -f $ctr >/dev/null 2>&1 || true' EXIT

podman run -it --name $ctr localhost:5001/sandbox-installs:local \
  zsh -lc 'claude /login || true'

podman cp $ctr:/home/ko/.claude/.credentials.json $dest 2>/dev/null || :>$dest

[[ -s $dest ]] || fn-exit-with 1 "${0:t}: login container captured no credential; a session would find no claude authentication"

print -r -- "${0:t}: captured the claude credential from the login container"
##[<] 🤖🤖
