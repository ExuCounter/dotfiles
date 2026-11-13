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

it "every file in claude/hooks is linked into ~/.claude/hooks by name"
unlinked=""
for f in "$REPO_ROOT"/claude/hooks/*; do
  name="claude/hooks/$(basename "$f")"
  grep -qE "^\s+~/\.claude/hooks/$(basename "$f"): $name$" "$REPO_ROOT/install.conf.yaml" || unlinked="$unlinked $name"
done
if [ -z "$unlinked" ]; then pass; else fail "not linked:$unlinked"; fi

it "skillshare's global config sits outside a skillshare/ folder, which skillshare reads as a project's"
if [ ! -e "$REPO_ROOT/skillshare/config.yaml" ] && grep -qE '^\s+~/\.config/skillshare/config\.yaml: skillshare-global/config\.yaml$' "$REPO_ROOT/install.conf.yaml"; then pass; else fail "skillshare/config.yaml would parse as a project config"; fi
