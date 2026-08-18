#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
typeset -i cpus=${PODMAN_MACHINE_CPUS:-6}
typeset -i memory=${PODMAN_MACHINE_MEMORY:-8192}
typeset -i disk=${PODMAN_MACHINE_DISK:-60}

(( $+commands[podman] )) || fn-exit-with 1 "${0:t}: podman not found"

podman machine inspect >/dev/null 2>&1 \
  || podman machine init --cpus $cpus --memory $memory --disk-size $disk

[[ $(podman machine inspect --format '{{.Rootful}}' 2>/dev/null) == true ]] || {
  podman machine stop >/dev/null 2>&1 || true
  podman machine set --rootful
}

[[ $(podman machine inspect --format '{{.State}}' 2>/dev/null) == running ]] \
  || podman machine start

podman info >/dev/null
##[<] 🤖🤖
