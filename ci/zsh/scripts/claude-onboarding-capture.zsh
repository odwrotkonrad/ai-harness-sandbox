#!/bin/zsh

emulate -LR zsh
setopt errexit pipefail
autoload -Uz fn-exit-with

##[>] 🤖🤖
#[why] a valid credential is not enough for an interactive run: claude treats a profile with no
#   onboarding state as a first run and walks the theme picker and the login screen before it will
#   start. these keys are what mark the profile as already set up, taken from the host that is
#   already onboarded. non-interactive runs never hit this, which is why -p worked throughout
typeset dest=${1:?dest path required}
typeset src=${CLAUDE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/claude}/.claude.json

:>$dest
chmod 600 $dest

[[ -s $src ]] || fn-exit-with 1 "${0:t}: no host claude profile at $src; an interactive session would be asked to onboard"

#[why] identity and onboarding state only: the host's project list, history and tips are its own
python3 -c '
import json, sys

src = json.load(open(sys.argv[1]))
keep = {}
for key in ("hasCompletedOnboarding", "lastOnboardingVersion", "oauthAccount", "theme"):
    if key in src and src[key] is not None:
        keep[key] = src[key]

if "hasCompletedOnboarding" not in keep:
    sys.exit("the host profile is not onboarded itself")

json.dump(keep, open(sys.argv[2], "w"), indent=2)
' $src $dest

[[ -s $dest ]] || fn-exit-with 1 "${0:t}: captured no onboarding state"

print -r -- "${0:t}: captured the host's claude onboarding state"
##[<] 🤖🤖
