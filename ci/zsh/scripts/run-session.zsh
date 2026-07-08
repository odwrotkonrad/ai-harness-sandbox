#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖🤖
typeset session=${SESSION:-s-$(date +%Y%m%d-%H%M%S)}
typeset -a kc=( kubectl --context kind-sandbox )

(( $+commands[kubectl] )) || fn-exit-with 1 "${0:t}: kubectl not found"

#[why] pod + pvc applied only when the pod is absent: reattach hits the running pod untouched
if ! $kc get pod $session >/dev/null 2>&1; then
  $kc apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${session}-home
  labels: {app: claude-sandbox, session: "${session}"}
spec:
  accessModes: [ReadWriteOnce]
  resources: {requests: {storage: 16Gi}}
---
apiVersion: v1
kind: Pod
metadata:
  name: ${session}
  labels: {app: claude-sandbox, session: "${session}"}
spec:
  restartPolicy: Always
  initContainers:
    - name: seed-home
      image: sandbox:local
      imagePullPolicy: Never
      securityContext: {runAsUser: 0}
      command: [sh, -c, 'if [ -z "\$(ls -A /mnt/home)" ]; then cp -a /home/ko/. /mnt/home/; fi']
      volumeMounts: [{name: home, mountPath: /mnt/home}]
  containers:
    - name: sandbox
      image: sandbox:local
      imagePullPolicy: Never
      command: [sleep, infinity]
      volumeMounts: [{name: home, mountPath: /home/ko}]
  volumes:
    - name: home
      persistentVolumeClaim: {claimName: ${session}-home}
EOF
fi

$kc wait --for=condition=Ready pod/$session --timeout=300s
exec $kc exec -it $session -- zsh -l
##[<] 🤖🤖🤖
