#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
typeset -a kc=( kubectl --context kind-sandbox )

(( $+commands[kubectl] )) || fn-exit-with 1 "${0:t}: kubectl not found"
[[ -n ${SESSION-} ]] || fn-exit-with 1 "${0:t}: SESSION required"

$kc delete pod $SESSION --ignore-not-found
#[why] home diffs live as subdirs on the shared sandbox-home PVC: wipe this session's dir via a one-shot pod
$kc run ${SESSION}-rm --rm -i --restart=Never --image=sandbox:local --overrides='{
  "spec": {
    "containers": [{
      "name": "rm",
      "image": "sandbox:local",
      "imagePullPolicy": "Never",
      "command": ["sh", "-c", "rm -rf /mnt/home/'$SESSION'"],
      "volumeMounts": [{"name": "home", "mountPath": "/mnt/home"}]
    }],
    "volumes": [{"name": "home", "persistentVolumeClaim": {"claimName": "sandbox-home"}}]
  }
}'
##[<] 🤖🤖
