#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
typeset repo_root=$(git -C ${0:A:h} rev-parse --show-toplevel)
source $repo_root/ci/zsh/lib/session-lib.zsh

typeset -i failed=0
typeset step=''

fn-step() {
  step=$1
  print -r -- "\n=== $step ==="
}

fn-fail() {
  failed=1
  print -ru2 -- "e2e: FAILED at step: $step: $1"
  print -ru2 -- 'e2e: leaving the cluster and sessions in place for diagnosis'
  exit 1
}

fn-assert() {
  print -r -- "  ok: $1"
}

#[why] the layer builds run for tens of minutes with nothing to show for it if their output is
#   discarded, which reads as a hang. stream it indented so progress is visible and the ok: lines
#   still stand out
fn-run() {
  "$@" 2>&1 | sed 's/^/  | /'
  return $pipestatus[1]
}

#[why] bootstrapping from nothing is what the scenario asks for, but proving it costs a ~40 minute
#   rebuild of all three layers. E2E_SCRATCH=1 buys that proof; by default the run reuses what is
#   already built, and the steps below are idempotent enough to be honest either way
fn-step 'clean host'
if [[ ${E2E_SCRATCH-} == 1 ]] {
  fn-run make -C $repo_root prune || fn-fail 'pruning the previous cluster and images'
  fn-assert 'no cluster and no sandbox images remain'
} else {
  fn-assert 'reusing the existing cluster and images (E2E_SCRATCH=1 to build from nothing)'
}

fn-step 'cluster bootstrap'
fn-run make -C $repo_root registry-up cluster-up cilium-up netpol-up \
  || fn-fail 'bringing the cluster up'
[[ $($SANDBOX_KC get nodes -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}') == *True* ]] \
  || fn-fail 'nodes are not Ready'
fn-assert 'cluster is up and its nodes are Ready'

$SANDBOX_KC get ciliumnetworkpolicy sandbox-default-deny >/dev/null 2>&1 \
  || fn-fail 'the default-deny egress policy is absent'
fn-assert 'cilium is enforcing the default-deny policy'

fn-step 'build all three layers'
fn-run make -C $repo_root image-build-base || fn-fail 'building the base layer'
fn-assert 'base layer built'
print -r -- '  (the installs layer runs che install-packages: tens of minutes, mostly quiet)'
fn-run make -C $repo_root image-build-installs || fn-fail 'building the installs layer'
fn-assert 'installs layer built'
fn-run make -C $repo_root image-build-config || fn-fail 'building the config layer'
fn-assert 'config layer built'

#[why] the first session pulls the whole config image onto the node, which takes minutes. tee the
#   output so the wait is visible, then read the name back from it
fn-create-session() {
  typeset log=$(mktemp)
  SESSION= $repo_root/ci/zsh/scripts/session-create.zsh 2>&1 | tee >(sed 's/^/  | /' >&2) >$log
  sed -n 's/.*session \(.*\) ready/\1/p' $log
  rm -f $log
}

fn-step 'session-create'
print -r -- '  (the first session pulls the config image onto the node: several minutes)'
typeset one=$(fn-create-session)
[[ -n $one ]] || fn-fail 'session-create produced no session'
fn-assert "created session $one"
[[ $one == *-*-*-* ]] || fn-fail "session name $one is not a four-word mnemonic"
fn-assert 'the name is a mnemonic, not a timestamp'

fn-step 'session runs unprivileged as the session user'
[[ $($SANDBOX_KC exec ${one}-0 -c sandbox -- id -u) == 1000 ]] \
  || fn-fail 'the session is not running as uid 1000'
fn-assert 'session runs as uid 1000, not root'
[[ $($SANDBOX_KC get pod ${one}-0 -o jsonpath='{.spec.containers[0].securityContext.privileged}') != true ]] \
  || fn-fail 'the session container is privileged'
fn-assert 'the session container holds no privilege'

fn-step 'session writes to its persisted home'
$SANDBOX_KC exec ${one}-0 -c sandbox -- sh -c 'echo persisted-work >/home/ko/e2e-marker' \
  || fn-fail 'writing to /home/ko'
fn-assert 'wrote a marker into the persisted home'

fn-step 'egress is denied by default and allowed where named'
$SANDBOX_KC exec ${one}-0 -c sandbox -- timeout 10 curl -sS -o /dev/null --max-time 8 https://example.com 2>/dev/null \
  && fn-fail 'an unlisted destination was reachable' || :
fn-assert 'an unlisted destination is denied'

fn-step 'session-create makes a second session'
typeset two=$(fn-create-session)
[[ -n $two && $two != $one ]] || fn-fail 'the second session did not get a distinct name'
fn-assert "created a second, distinctly named session $two"

fn-step 'session-ls lists the running sessions'
typeset listing=$($repo_root/ci/zsh/scripts/session-ls.zsh)
[[ $listing == *$one* && $listing == *$two* ]] || fn-fail 'session-ls omitted a running session'
fn-assert 'both sessions are listed as running'

fn-step 'session-stop keeps the data'
SESSION=$two $repo_root/ci/zsh/scripts/session-stop.zsh >/dev/null || fn-fail 'stopping a session'
[[ $($SANDBOX_KC get statefulset $two -o jsonpath='{.spec.replicas}') == 0 ]] \
  || fn-fail 'the stopped session was not scaled to 0'
fn-assert 'the stopped session released its compute'
$SANDBOX_KC get pvc home-${two}-0 >/dev/null 2>&1 || fn-fail 'the stopped session lost its volume'
fn-assert 'the stopped session kept its volume'

fn-step 'session-ls shows stopped sessions on request'
[[ $(SESSION_STOPPED=1 $repo_root/ci/zsh/scripts/session-ls.zsh) == *$two* ]] \
  || fn-fail 'session-ls --stopped omitted the stopped session'
fn-assert 'the stopped session is listed on request'

fn-step 'session-rename keeps the data and refuses a collision'
SESSION=$one SESSION_NEW=$two $repo_root/ci/zsh/scripts/session-rename.zsh $one $two >/dev/null 2>&1 \
  && fn-fail 'a colliding rename was allowed' || :
fn-assert 'a colliding rename is refused'

typeset renamed=renamed-${one}
$repo_root/ci/zsh/scripts/session-rename.zsh $one $renamed >/dev/null \
  || fn-fail 'renaming a session'
$SANDBOX_KC rollout status statefulset/$renamed --timeout=900s >/dev/null \
  || fn-fail 'the renamed session did not come back'
[[ $($SANDBOX_KC exec ${renamed}-0 -c sandbox -- cat /home/ko/e2e-marker 2>/dev/null) == persisted-work ]] \
  || fn-fail 'the renamed session lost its data'
fn-assert 'the renamed session kept its data'

fn-step 'session-update-config rebuilds and keeps persisted work'
fn-run make -C $repo_root session-update-config || fn-fail 'updating the configuration'
$SANDBOX_KC rollout status statefulset/$renamed --timeout=900s >/dev/null \
  || fn-fail 'the session did not come back after the update'
[[ $($SANDBOX_KC exec ${renamed}-0 -c sandbox -- cat /home/ko/e2e-marker 2>/dev/null) == persisted-work ]] \
  || fn-fail 'work persisted before the update did not survive it'
fn-assert 'work persisted before the update survived it'

fn-step 'session-rm removes the session and its volume'
SESSION=$renamed $repo_root/ci/zsh/scripts/session-rm.zsh >/dev/null || fn-fail 'removing a session'
SESSION=$two $repo_root/ci/zsh/scripts/session-rm.zsh >/dev/null || fn-fail 'removing the stopped session'
$SANDBOX_KC get pvc home-${renamed}-0 >/dev/null 2>&1 \
  && fn-fail 'the removed session leaked its volume' || :
fn-assert 'removing a session deletes its volume too'

#[why] the cluster and its three image layers cost ~40 minutes to rebuild, so the test keeps them by
#   default and leaves teardown to whoever wants a clean host: E2E_TEARDOWN=1
fn-step 'teardown'
if [[ ${E2E_TEARDOWN-} == 1 ]] {
  fn-run make -C $repo_root cluster-down || fn-fail 'tearing the cluster down'
  fn-assert 'the cluster it created is gone'
} else {
  fn-assert 'kept the cluster and images (E2E_TEARDOWN=1 to delete them)'
}

print -r -- '\ne2e: PASSED'
##[<] 🤖🤖
