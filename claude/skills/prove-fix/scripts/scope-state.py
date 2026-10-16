#!/usr/bin/env python3
"""Keeps only the app's own cookies and storage in an agent-browser state file, in place,
so an identity provider's session never reaches the work session.

Usage: scope-state.py <state.json> <app origin>      e.g. http://localhost:8080

Prints how many cookies and origins it kept, never a value.
"""
import json
import os
import sys
import urllib.parse


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    path, origin = sys.argv[1], sys.argv[2].rstrip("/")
    host = urllib.parse.urlsplit(origin).hostname
    if not host:
        sys.exit(f"scope-state.py: no host in {origin}")
    with open(path) as file:
        state = json.load(file)

    def ours(cookie):
        domain = cookie.get("domain", "").lstrip(".").lower()
        return bool(domain) and (domain == host or host.endswith("." + domain))

    cookies, origins = state.get("cookies", []), state.get("origins", [])
    state["cookies"] = [cookie for cookie in cookies if ours(cookie)]
    state["origins"] = [entry for entry in origins if entry.get("origin", "").rstrip("/") == origin]
    scoped = path + ".scoped"
    with os.fdopen(os.open(scoped, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), "w") as file:
        json.dump(state, file)
    os.chmod(scoped, 0o600)
    os.replace(scoped, path)
    print(f"kept {len(state['cookies'])} of {len(cookies)} cookies and {len(state['origins'])} of {len(origins)} origins")


if __name__ == "__main__":
    main()
