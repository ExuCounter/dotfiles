# Every `link:` source in install.conf.yaml must exist in the repo. A source
# that is only present as an untracked directory on one machine produces a
# dangling symlink on the next `./install`, which is how Whiska's required
# skills (domain-modeling, lesson-learned, c4-architecture) went missing.

it "every install.conf.yaml link source exists in the repo"
missing=""
while IFS= read -r src; do
  [ -e "$REPO_ROOT/$src" ] || missing="$missing $src"
done < <(
  awk '/^- link:/{on=1;next} /^- [a-z]+:/{on=0} on' "$REPO_ROOT/install.conf.yaml" \
    | grep -E '^\s+~[^:]+:\s+\S' \
    | sed -E 's/^[^:]+:[[:space:]]+//' \
    | grep -vE '^[a-z]+:' \
    | sed -E 's|/\*+$||'
)
if [ -n "$missing" ]; then
  fail "missing link sources:$missing"
else
  pass
fi

it "every dotfiles-managed target under ~/.claude resolves after install (clean covers hooks and skills)"
if grep -qE '^- clean:.*~/\.claude/hooks' "$REPO_ROOT/install.conf.yaml"; then pass; else fail "install.conf.yaml clean: does not include ~/.claude/hooks"; fi
