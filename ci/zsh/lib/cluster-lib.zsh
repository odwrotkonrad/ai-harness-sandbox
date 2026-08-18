##[>] 🤖🤖
#[why] `kind get clusters` is broken under the podman provider: podman 6's --format rejects kind's
#   go template ("cannot index slice/array with type string"), so it exits 1 printing nothing. every
#   guard built on it reads as "no cluster" and cluster-up then fails on nodes that already exist.
#   ask podman for the node container directly instead
fn-sandbox-cluster-exists() {
  podman container exists sandbox-control-plane 2>/dev/null
}

#[why] a host reboot leaves the nodes present but exited, which "exists" alone reports as a cluster.
#   starting them back is what makes the cluster usable again, and kind cannot do it itself
fn-sandbox-cluster-running() {
  [[ $(podman inspect -f '{{.State.Running}}' sandbox-control-plane 2>/dev/null) == true ]]
}

fn-sandbox-cluster-start() {
  typeset node
  for node in ${(f)"$(podman ps -a --filter label=io.x-k8s.kind.cluster=sandbox --format '{{.Names}}' 2>/dev/null)"}; do
    [[ -n $node ]] && podman start $node >/dev/null
  done
}
##[<] 🤖🤖
