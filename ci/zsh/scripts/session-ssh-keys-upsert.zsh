#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with fn-log-msg

##[>] 🤖🤖
typeset repo_root=$(git -C ${0:A:h} rev-parse --show-toplevel)
source $repo_root/ci/zsh/lib/session-lib.zsh

fn-sandbox-require ${0:t}

typeset ssh_dir=${SANDBOX_SSH_DIR:-$HOME/.ssh}
typeset -a args=()

#[why] signing only, never id_access: a session authenticates to gitlab with the group token baked
#   under its own identity, so it needs no ssh access key. commit signing is the one thing it cannot
#   do without a private key, so that is the only one handed over
for key in id_signing id_signing.pub; do
  [[ -s $ssh_dir/$key ]] && args+=( --from-file=$key=$ssh_dir/$key )
done

if (( ! $#args )) {
  fn-log-msg -t ${0:t} "no keys in $ssh_dir; sessions will start without a signing key and git commit will fail"
  exit 0
}

$SANDBOX_KC create secret generic sandbox-ssh-keys $args \
  --dry-run=client -o yaml | $SANDBOX_KC apply -f - >/dev/null

fn-log-msg -t ${0:t} "sandbox-ssh-keys: ${#args} key(s) from $ssh_dir"
##[<] 🤖🤖
