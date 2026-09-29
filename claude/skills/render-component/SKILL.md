---
name: render-component
description: "Render one component on its own and show the user a picture of it, with no login and no clicking through the app. Use when the user wants to see, preview, screenshot or visually check a component that already exists — \"show me what OrderSummary looks like\", \"what does its empty state render as\" — or says the real page is behind auth or too many steps away. For choosing between design directions before building, use frontend-preview instead."
---

# Render a component in isolation

The user wants to look at one component. The component lives eight clicks past a login.
A browser can only open URLs, so the job is to give that component a URL of its own, and
photograph what comes back.

Everything you build here is a **harness**: throwaway scaffolding that exists to hold the
component up to the light. It is deleted in step 5. The component itself is never edited
— the moment you change the thing you were asked to look at, the picture stops being
evidence.

Use the dev server, not a hand-written HTML page. Rendering the component through the app
that owns it is what gets you the real CSS pipeline, the real fonts and the real design
tokens; a page written from memory loses all three at once and the user reads the losses
as the component being broken.

## Step 1 — Find out what it needs

Read the component, and name every way it reaches outside itself. This is the whole
difference between one screenshot and forty minutes of blank pages:

- **Props.** Which are required, and what shape. Read the props type or `defineProps`.
- **Context.** Grep the file and its direct imports for `useContext(`, `inject(`, and the
  app's own wrappers — `useAuth`, `useUser`, `useStore`, `useQuery`, `useRouter`,
  `useRoute`, `useTranslation`, `useI18n`. Each one is a provider you will supply.
- **Network.** Does it, or a child, call out? Every transport it uses has to be stubbed —
  and a dev server that proxies `/api` to staging carries your real cookies, so an
  un-stubbed call is an authenticated one. `harness.md` says what a `fetch` stub does and
  does not cover.
- **Children and slots.** A component that renders `{children}` or `<slot />` shows
  nothing without them.

An **existing sandbox beats a new harness.** If the repo runs Storybook, Histoire or
Ladle, a story is cheaper than anything below and the app stays untouched — open the
story URL and skip to step 3. Check for `.storybook/`, `histoire.config.*`, `.ladle/`.

Tell the user in one line what the component depends on, before you build anything.

Done when every outside reach has a named fake waiting for it.

## Step 2 — Mount it on a URL

Get the dev server running with the **`run` skill** — it already knows how this project
launches. You need a URL and a port.

Then mount the component. **Where** it mounts is per-framework and is written down once,
in [`../frontend-preview/references/preview-routes.md`](../frontend-preview/references/preview-routes.md)
— the route file for each framework, the dev guard, the traps. Read it; it is shared with
the `frontend-preview` skill and is the single copy. One place this skill departs from it,
and `harness.md` says where and why: that file mounts a *page* inside the real layout,
while a component needs an instance you control.

**What** you wrap the component in is this skill's half, with verified React and Vue
scaffolds in [`references/harness.md`](references/harness.md). Read that before writing
the harness file.

Four rules hold the harness to disposable:

- **Name it `preview__`.** One greppable token. A *leading* underscore means "private,
  not a route" in Next.js, so `__preview` 404s — measured, which is why the convention
  reads backwards.
- **Guard it to development**, so it is inert if it ever escapes: `import.meta.env.DEV`
  for Vite, `process.env.NODE_ENV !== 'development'` for Next.
- **Additive only.** A new harness file, and at most one branch in an entry point. The
  component under the lens is read, never written.
- **Fixtures are fake.** Invented names, invented numbers, shaped like the real thing.
  Never a copied user record.

Give the fixture the shape that actually stresses the layout — a long name, a six-item
list, a big number. `Item 1 / Item 2` hides exactly what the user is looking for.

## Step 3 — Photograph it

Capture with `frontend-preview-shot.sh` (dotfiles-managed, on `PATH`). It drives headless
Chrome, installs nothing into the project, and fails loudly on the captures that look like
success everywhere except a human's eyes:

```bash
frontend-preview-shot.sh --width 900 --height 600 --wait 2500 --stable \
  "http://localhost:5173/?preview__=order-summary" \
  .frontend-preview/<slug>/order-summary.png
```

`--stable` shoots again at double the wait and requires the two to agree, which is how a
half-hydrated component gets caught. The full exit-code table is in
[`../frontend-preview/SKILL.md`](../frontend-preview/SKILL.md); one code matters more
here than there:

**Exit 4 — "looks blank" — is almost always the component throwing.** React unmounts the
whole tree on an uncaught render error; Vue renders nothing for the failing component. In
a harness the previewed component *is* the tree, so both end at the same place: a valid
PNG of a white page. Measured on a missing provider: exit 4, every time. So on exit 4,
read the browser console before touching `--wait`:

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu \
  --user-data-dir="$(mktemp -d)" \
  --enable-logging=stderr --virtual-time-budget=4000 --dump-dom "<url>" 2>&1 >/dev/null |
  grep ':CONSOLE:'
```

Grep for `:CONSOLE:` and nothing looser. Chrome prints a wall of its own `ERROR:` lines
about display links and certificates on macOS and still works fine; `:CONSOLE:` is the
page talking, and it is the only part that is about your harness. The throwaway
`--user-data-dir` keeps the run out of the user's real Chrome profile, so the page loads
logged out rather than with their live session.

`Uncaught Error: useAuth must be used within AuthProvider` is a provider missing from
step 1's list. Go add it.

Then **read the PNG back yourself**. The script catches a blank page and a page with no
stylesheet; it cannot tell a rendered component from a rendered error state, and that is
the failure this skill exists to avoid shipping.

Read the **whole frame**, not just the component. Your fixture is fake; anything the
surrounding real layout drew is not. Mounting inside the app's own layout — which is what
a Next.js route group gets you — renders that layout against the developer's live
session: their name, their org, a customer list in a sidebar. Crop it out, or reshoot
against a logged-out or seeded state, before step 4 puts the picture anywhere.

## Step 4 — Show it

One component in one state: put the screenshot in the reply and say in a line what the
fixture was and what you noticed — a console warning, text overflowing, a translation key
showing raw.

More than one state or viewport — empty, loading, error, long text, mobile — is a page,
not a reply. Load the `artifact-design` skill and publish the shots as one Artifact,
each labelled with the state it is. Variants come from editing the fixture in the harness
file and shooting again; `--width 390 --height 844` gets you mobile.

## Step 5 — Delete the harness

Before the turn ends, whatever the user does next. Delete the harness **directory first**,
the entry-point branch second — the branch is the thread that leads back to the files, so
cutting it first leaves them orphaned and findable only by path.

```bash
find . -path '*preview__*' -not -path './node_modules/*' -not -path './.git/*'
grep -rn "preview__" --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=.next .
git status --short
git diff HEAD --stat
```

Both searches have to come back empty, and you need both: the harness files carry
`preview__` in their **path**, not their contents, so the grep alone reports a clean tree
while `src/preview__/` is still sitting there.

The entry-point branch is the one that gets forgotten, because it lives in a file that was
already there. If getting the harness up meant installing anything, `package.json` and the
lockfile are part of the harness too. Leave the harness uncommitted while it exists — once
it is in a commit, `git status` comes back clean and says nothing.

Then confirm the guard did its job, rather than trusting it: production-build once and grep
the output for a distinctive fixture string. `harness.md` says what that check catches.

The PNGs can stay until the work merges **if** they are ignored —
`git check-ignore .frontend-preview/` answers that, and this is a user-level setting that
is not on every machine. If it is not ignored, delete them now.
