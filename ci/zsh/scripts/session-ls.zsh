#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖🤖
typeset -a kc=( kubectl --context kind-sandbox )

(( $+commands[kubectl] )) || fn-exit-with 1 "${0:t}: kubectl not found"

print 'RUNNING SESSIONS'
$kc get pods -l app=claude-sandbox 2>/dev/null

print '\nSESSION HOME DIFFS (running + stopped)'
typeset lister=session-ls-$(date +%s)
$kc run $lister --restart=Never --image=localhost:5001/sandbox:local --attach=false --overrides='{
  "spec": {
    "containers": [{
      "name": "ls",
      "image": "localhost:5001/sandbox:local",
      "imagePullPolicy": "IfNotPresent",
      "command": ["sh", "-c", "d=$(du -sh /mnt/home/* 2>/dev/null); [ -n \"$d\" ] && echo \"$d\" || echo none"],
      "volumeMounts": [{"name": "home", "mountPath": "/mnt/home"}]
    }],
    "volumes": [{"name": "home", "persistentVolumeClaim": {"claimName": "sandbox-home"}}]
  }
}' >/dev/null
$kc wait --for=jsonpath='{.status.phase}'=Succeeded pod/$lister --timeout=30s >/dev/null 2>&1 || true
$kc logs $lister 2>/dev/null
$kc delete pod $lister --wait=false >/dev/null 2>&1
##[<] 🤖🤖🤖
