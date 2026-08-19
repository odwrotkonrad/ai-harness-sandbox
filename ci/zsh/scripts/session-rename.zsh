#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
typeset repo_root=$(git -C ${0:A:h} rev-parse --show-toplevel)
source $repo_root/ci/zsh/lib/session-lib.zsh

typeset from=${1:-${SESSION-}}
typeset to=${2:-${SESSION_NEW-}}

fn-sandbox-require ${0:t}
[[ -n $from ]] || fn-exit-with 1 "${0:t}: source session required (session-rename <from> <to>)"
[[ -n $to ]] || fn-exit-with 1 "${0:t}: target name required (session-rename <from> <to>)"
[[ $to =~ '^[a-z0-9]([a-z0-9-]*[a-z0-9])?$' ]] \
  || fn-exit-with 1 "${0:t}: $to is not a valid name (lowercase, digits, hyphens)"

fn-sandbox-exists $from || fn-exit-with 1 "${0:t}: session $from does not exist"
fn-sandbox-exists $to && fn-exit-with 1 "${0:t}: session $to already exists; rename refused"

typeset pv=$($SANDBOX_KC get pvc home-${from}-0 -o jsonpath='{.spec.volumeName}' 2>/dev/null)
[[ -n $pv ]] || fn-exit-with 1 "${0:t}: session $from has no bound volume"

typeset -i was_running=1
[[ $($SANDBOX_KC get statefulset $from -o jsonpath='{.spec.replicas}') == 0 ]] && was_running=0

#[why] read before the delete takes it away: the volume keeps whatever seeded it, so a rename must
#   carry the old stamp rather than restamp the home as freshly seeded from the current image
typeset seed_digest=$($SANDBOX_KC get statefulset $from \
  -o jsonpath='{.spec.template.metadata.annotations.sandbox/image-digest}' 2>/dev/null)

$SANDBOX_KC patch pv $pv -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}' >/dev/null

$SANDBOX_KC delete statefulset $from --cascade=foreground >/dev/null
$SANDBOX_KC delete pvc home-${from}-0 >/dev/null
$SANDBOX_KC patch pv $pv -p '{"spec":{"claimRef":null}}' >/dev/null

$SANDBOX_KC apply -f - <<EOF >/dev/null
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: home-${to}-0
  labels: {app: claude-sandbox, session: ${to}}
spec:
  accessModes: [ReadWriteOnce]
  resources: {requests: {storage: 16Gi}}
  volumeName: ${pv}
EOF

SESSION=$to SANDBOX_IMAGE_DIGEST=$seed_digest \
  yq '(.. | select(tag == "!!str")) |= envsubst' $repo_root/ci/k8s/session.yml \
  | $SANDBOX_KC apply -f - >/dev/null

(( was_running )) || $SANDBOX_KC scale statefulset/$to --replicas=0 >/dev/null

$SANDBOX_KC patch pv $pv -p '{"spec":{"persistentVolumeReclaimPolicy":"Delete"}}' >/dev/null

print -r -- "${0:t}: session $from renamed to $to; its data is intact"
##[<] 🤖🤖
