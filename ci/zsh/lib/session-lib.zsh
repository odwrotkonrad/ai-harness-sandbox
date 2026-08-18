##[>] 🤖🤖
typeset -ga SANDBOX_KC=( kubectl --context kind-sandbox )

fn-sandbox-require() {
  (( $+commands[kubectl] )) || fn-exit-with 1 "${1}: kubectl not found"
}

#[why] the digest of the config image a new session would be seeded from, so a session can be told
#   whether its home predates the current build. empty when the image is absent, which reads as
#   "cannot tell" rather than "stale"
fn-sandbox-image-digest() {
  podman image inspect localhost:5001/sandbox:local --format '{{index .RepoDigests 0}}' 2>/dev/null \
    | sed 's/.*@//'
}

fn-sandbox-seeded-digest() {
  $SANDBOX_KC exec ${1}-0 -c sandbox -- cat /home/ko/.sandbox-seeded 2>/dev/null | tr -d '[:space:]'
}

fn-sandbox-name() {
  typeset -a adjectives=(brave calm clever eager fierce gentle jolly keen lively merry noble proud quick swift witty bold)
  typeset -a colours=(amber azure coral crimson emerald golden indigo ivory jade lilac olive scarlet teal violet copper slate)
  typeset -a creatures=(badger falcon heron ibex jaguar kestrel lemur marten otter panda quail raven stoat tapir walrus yak)
  typeset -a things=(anchor beacon compass ember harbor kettle lantern marble needle orchard pebble quartz ribbon satchel thimble vessel)
  print -r -- "${adjectives[RANDOM % $#adjectives + 1]}-${colours[RANDOM % $#colours + 1]}-${creatures[RANDOM % $#creatures + 1]}-${things[RANDOM % $#things + 1]}"
}

fn-sandbox-new-name() {
  typeset candidate
  repeat 50 {
    candidate=$(fn-sandbox-name)
    $SANDBOX_KC get statefulset $candidate >/dev/null 2>&1 || { print -r -- $candidate; return 0 }
  }
  fn-exit-with 1 "${1}: could not find a free session name"
}

fn-sandbox-sessions() {
  $SANDBOX_KC get statefulset -l app=claude-sandbox -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null
}

fn-sandbox-running-sessions() {
  $SANDBOX_KC get statefulset -l app=claude-sandbox \
    -o jsonpath='{range .items[?(@.spec.replicas>0)]}{.metadata.name}{"\n"}{end}' 2>/dev/null
}

fn-sandbox-exists() {
  $SANDBOX_KC get statefulset $1 >/dev/null 2>&1
}

fn-sandbox-pick() {
  typeset -a options=( ${(f)1} )
  typeset choice
  (( $#options )) || return 1
  if (( $#options == 1 )) { print -r -- $options[1]; return 0 }

  [[ -t 0 ]] || {
    print -ru2 -- "several sessions and no terminal to pick with; name one with SESSION=: ${(j:, :)options}"
    return 1
  }

  print -r -- 'several sessions; pick one:' >&2
  select choice in $options; do
    [[ -n $choice ]] && { print -r -- $choice; return 0 }
  done
  return 1
}
##[<] 🤖🤖
