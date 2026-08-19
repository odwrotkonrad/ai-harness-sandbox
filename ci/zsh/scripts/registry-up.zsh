#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
(( $+commands[podman] )) || fn-exit-with 1 "${0:t}: podman not found"

${0:A:h}/machine-up.zsh

#[why] three states, not two: absent, present but stopped (what a host reboot leaves behind), and
#   running. creating over a stopped container fails on the name already being taken
if { podman container exists kind-registry } {
  [[ $(podman inspect -f '{{.State.Running}}' kind-registry 2>/dev/null) == true ]] \
    || podman start kind-registry >/dev/null
} else {
  podman run -d --restart=always --name kind-registry -p 127.0.0.1:5001:5000 docker.io/library/registry:2 >/dev/null
}

podman network connect kind kind-registry 2>/dev/null || true
##[<] 🤖🤖
