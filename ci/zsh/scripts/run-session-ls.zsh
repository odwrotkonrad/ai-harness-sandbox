#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
typeset -a kc=( kubectl --context kind-sandbox )

(( $+commands[kubectl] )) || fn-exit-with 1 "${0:t}: kubectl not found"

$kc get pods -l app=claude-sandbox
#[why] stopped sessions have no pod: their home diffs on the shared PVC are the session list
$kc run session-ls --rm -i --restart=Never --image=sandbox:local --overrides='{
  "spec": {
    "containers": [{
      "name": "ls",
      "image": "sandbox:local",
      "imagePullPolicy": "Never",
      "command": ["sh", "-c", "du -sh /mnt/home/* 2>/dev/null || echo \"no session homes\""],
      "volumeMounts": [{"name": "home", "mountPath": "/mnt/home"}]
    }],
    "volumes": [{"name": "home", "persistentVolumeClaim": {"claimName": "sandbox-home"}}]
  }
}'
##[<] 🤖🤖
