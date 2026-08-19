#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
typeset repo_root=$(git -C ${0:A:h} rev-parse --show-toplevel)
export KIND_EXPERIMENTAL_PROVIDER=podman

(( $+commands[kind] )) || fn-exit-with 1 "${0:t}: kind not found"
(( $+commands[podman] )) || fn-exit-with 1 "${0:t}: podman not found"
(( $+commands[kubectl] )) || fn-exit-with 1 "${0:t}: kubectl not found"

source $repo_root/ci/zsh/lib/cluster-lib.zsh

${0:A:h}/machine-up.zsh

#[why] a host reboot leaves the nodes exited: start them rather than create over them, and give the
#   api server a moment to answer before anything downstream talks to it
if { fn-sandbox-cluster-exists } {
  if { ! fn-sandbox-cluster-running } {
    print -r -- "${0:t}: the cluster's nodes are stopped; starting them"
    fn-sandbox-cluster-start
    kubectl --context kind-sandbox wait --for=condition=Ready nodes --all --timeout=300s >/dev/null
  }
} else {
  kind create cluster --name sandbox --config $repo_root/ci/k8s/kind.yml
}

podman network connect kind kind-registry 2>/dev/null || true

kubectl --context kind-sandbox apply -f $repo_root/ci/k8s/limits.yml
##[<] 🤖🤖
