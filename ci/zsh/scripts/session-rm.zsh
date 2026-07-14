#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖🤖
typeset -a kc=( kubectl --context kind-sandbox )

(( $+commands[kubectl] )) || fn-exit-with 1 "${0:t}: kubectl not found"
[[ -n ${SESSION-} ]] || fn-exit-with 1 "${0:t}: SESSION required"

$kc delete pod $SESSION --ignore-not-found

#[why] home diffs live as subdirs on the shared sandbox-home PVC: wipe this session's dir via a one-shot pod. --attach=false + wait-for-complete (not --rm -i) so the rm -rf actually finishes before the pod is torn down, and no interactive-tty banner / delete chatter leaks
#[why] privileged + runAsUser 0: the diff is an overlayfs dir (upper/ + work/), and the kernel-owned work/work subdir refuses unlink without CAP_DAC_OVERRIDE, so a plain rm fails "permission denied". the session pod runs privileged for the same reason
typeset remover=${SESSION}-rm
$kc run $remover --restart=Never --image=localhost:5001/sandbox:local --attach=false --overrides='{
  "spec": {
    "containers": [{
      "name": "rm",
      "image": "localhost:5001/sandbox:local",
      "imagePullPolicy": "IfNotPresent",
      "securityContext": {"privileged": true, "runAsUser": 0},
      "command": ["sh", "-c", "rm -rf /mnt/home/'$SESSION'"],
      "volumeMounts": [{"name": "home", "mountPath": "/mnt/home"}]
    }],
    "volumes": [{"name": "home", "persistentVolumeClaim": {"claimName": "sandbox-home"}}]
  }
}' >/dev/null
$kc wait --for=jsonpath='{.status.phase}'=Succeeded pod/$remover --timeout=30s >/dev/null 2>&1 || true
$kc delete pod $remover --wait=false >/dev/null 2>&1
##[<] 🤖🤖🤖
