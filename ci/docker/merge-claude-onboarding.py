##[>] 🤖🤖
"""Merge captured claude onboarding state into a profile, keeping what is already there."""

import json
import os
import sys

target, incoming = sys.argv[1], sys.argv[2]

merged = {}
if os.path.exists(target):
    try:
        merged = json.load(open(target))
    except ValueError:
        merged = {}

merged.update(json.load(open(incoming)))
json.dump(merged, open(target, "w"), indent=2)
##[<] 🤖🤖
