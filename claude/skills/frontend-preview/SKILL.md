---
name: frontend-preview
description: "Show a visual before/after with 2-3 design options as a published Artifact, and block for the user's pick, BEFORE writing any frontend implementation code. Use when a task changes what a user sees in a browser — a new page, a redesign, a component, layout, styling or copy change — or when the user invokes /frontend-preview."
---

# frontend-preview

Before writing a single line of frontend implementation code, show the user what they
have now, what they'd get, and the two or three directions it could go — as pictures,
in one page they can open on a phone. Then **stop** and let them choose.

The point is not to document your plan. It's to make the user's "no, not that one"
cost thirty seconds instead of four hundred lines.

## When this runs

Run it when the honest answer to this is yes:

> Would a screenshot of the app look different after this change?

That's the whole test. A new page, a redesign, a layout or spacing change, a component,
a state that renders differently, a copy change on a visible surface — yes. A renamed
API route, a query optimisation, a test, a build config — no, even if the word
"dashboard" appears in the request.

**Skip it, and say you're skipping it, when:**

- The change is visually trivial and has exactly one sensible form (fix a typo, bump one
  colour the user already named, revert a known-good commit).
- The user gave you a mock, a Figma frame, or a screenshot to match — the direction is
  already picked. Go implement it.
- The user explicitly says to just build it.

Never skip it silently. If you decide it doesn't apply, say so in one line and move on.

## What you must not do

Do not write, edit, or stage any file the application actually ships — no `src/`, no
`app/`, no `components/`, no stylesheets in the real tree — until the user has picked
an option. Everything you make in this skill is disposable and lives in
`.frontend-preview/`. If you catch yourself editing a real file "just to see it", stop:
that is the failure this skill exists to prevent.

## Step 1 — Scope the surface

Settle these before touching a browser. Work them out yourself where you can; ask only
what you genuinely can't determine:

- **Which surface?** The exact route (`/settings/billing`) or component. One surface per
  preview — if the task spans three pages, preview the one the decision hinges on and
  say which one you picked and why.
- **Which state?** Loaded with realistic data, empty, error, logged-out. Preview the
  state the change is actually about. An empty-state redesign previewed with full data
  is worthless.
- **Which viewports?** Default to desktop `1280x900`. Add mobile `390x844` when the
  change is layout- or navigation-shaped. Don't shoot three breakpoints out of habit —
  each one multiplies the images the user has to look at.

## Step 2 — Capture "what we had"

Get the app running and shoot the real current state. **Use the `run` skill** to find or
start the dev server — it already knows how this project launches, and duplicating that
logic here will rot. You need a URL.

Capture with `frontend-preview-shot.sh` (dotfiles-managed, on `PATH` as
`~/.config/bin/frontend-preview-shot.sh`). It drives headless Chrome — no install,
nothing added to the project — and, more importantly, it fails loudly when the capture
didn't actually work:

```bash
frontend-preview-shot.sh --width 1280 --height 900 --wait 3000 \
  "http://localhost:3000/settings/billing" \
  .frontend-preview/<slug>/shots/before-desktop.png
```

**Check the exit code every time.** Each failure is distinct and tells you what to do:

| Exit | Meaning | What to do |
|---|---|---|
| 0 | Captured and validated | Go on |
| 2 | Browser wrote nothing | Is the dev server actually serving that URL? |
| 3 | No usable browser | Install Chrome, or set `FRONTEND_PREVIEW_BROWSER` |
| 4 | **Capture looks blank** | Raise `--wait`; the page probably hadn't rendered |
| 5 | Output isn't a PNG | Something is badly wrong; report it, don't retry blindly |
| 64 | Bad arguments | Read the usage |

Exit 4 is the one that earns the script. A blank screenshot is a *valid PNG* — it looks
like success everywhere except a human's eyes, and shipping one makes the user think the
design is broken rather than the capture. The check is a density heuristic (bytes per
pixel against a measured threshold), so it can be wrong in both directions: pass
`--allow-blank` for a state that genuinely is empty, and **still read the PNG back
yourself** before building the artifact. The script catches the obvious catastrophe; your
eyes catch a half-rendered page, which it cannot.

Two more things worth knowing:

- Chrome prints alarming `ERROR:` lines about display links and task policies on macOS
  and still succeeds. The script judges by the file, not the stderr. So should you.
- Captures are viewport-sized, not full-page. For content below the fold pass a taller
  `--height` rather than hunting for a full-page flag — headless Chrome has none.

**If the surface doesn't exist yet** — a brand-new page — do not fake a "before". Render
an explicit `Nothing here yet — this surface is new` panel in that slot on the final
page. An invented before-state is worse than an empty one, because the user will believe it.

## Step 3 — Harvest the real design language

This is the step that decides whether the preview is honest or whether it's generic AI
mockup slop the user approves and then can't have.

Before you write any mockup markup, pull the project's actual visual vocabulary out of
the repo — read it, don't invent it:

- Design tokens / CSS custom properties (`:root {--...}`, theme files)
- Tailwind config, or whatever the utility/theme layer is
- The real font stack, spacing scale, radii, shadow scale
- An existing component that's close to what you're proposing, as a structural model

Inline what you find into the mockups. The test: a stranger should not be able to tell
the mockup screenshot from the real-app screenshot at a glance, except for the thing
you actually changed. If you couldn't find real tokens and had to guess, **say so on the
artifact** — label it "visual approximation" rather than letting it pass as accurate.

## Step 4 — Build the options

Write 2–3 standalone HTML files into `.frontend-preview/<slug>/`. Self-contained, inline
CSS, real-looking copy — never `Lorem ipsum`, never `Item 1 / Item 2 / Item 3`. Fake
data that looks nothing like real data hides exactly the layout problems the user needs
to see (long names, empty fields, big numbers).

**One of the options is always the smallest change that solves the problem.** Label it
plainly. The user must be able to choose boring on purpose — without that option present,
this step quietly becomes a redesign pitch.

Make the options genuinely *different directions*, not three shades of one idea. Two
options that differ only in padding is a waste of the user's attention; say "there's only
one sensible direction here" and show one, rather than padding the count.

For each option, write down in one sentence what it trades away. Every real option costs
something — more code, a new dependency, a slower page, a pattern that doesn't exist in
the codebase yet. An option list with no downsides listed is a sales pitch.

## Step 5 — Render the options

Same tool as step 2, pointed at the local file. A relative path is fine — it's resolved
to an absolute `file://` URL for you:

```bash
for opt in a b; do
  frontend-preview-shot.sh --width 1280 --height 900 \
    ".frontend-preview/<slug>/option-$opt.html" \
    ".frontend-preview/<slug>/shots/option-$opt.png" || exit 1
done
```

Shoot every option at the **same width** as the "before" capture. A comparison between
images of different widths is not a comparison, and the user will read the size
difference as a design difference.

Then read every PNG back before you go on.

## Step 6 — Publish the artifact

Load the `artifact-design` skill first, then write the comparison page and publish it
with the Artifact tool. Pass the PNGs as supporting files (a published artifact can't
load anything from outside itself, so images must either ride along in the `files` map
or be inlined as `data:` URIs):

```
Artifact(
  file_path: ".frontend-preview/<slug>/preview.html",
  files: {"shots/before-desktop.png": ".frontend-preview/<slug>/shots/before-desktop.png", ...},
  favicon: "...",
  description: "..."
)
```

The page must carry, in this order:

1. **One sentence on what's being decided.** The user may be opening this cold, hours
   later, from a worktree they've forgotten. No "as discussed".
2. **Before → After, side by side**, at the same width, so the comparison is honest.
3. **One card per option**: screenshot, a plain-language name, what it changes, what it
   costs, and roughly how much work it is.
4. **Your recommendation, with a reason.** Don't hide behind neutrality — you've looked
   at the code, you have a view. One option, one sentence why.
5. **How to answer**: "reply with A, B, or C" — and make clear they can also say
   "none of these".

Keep it to one screen of scrolling per viewport. This is a decision aid, not a
deliverable.

## Step 7 — Stop

End the turn. Write nothing else.

If you're in a worktree, the last line is:

```
[worktree-status: needs-decision] Frontend preview ready — pick A, B or C: <artifact URL>
```

In the user's main terminal, just give them the URL and the question.

**Do not start implementing your recommended option while you wait.** Not the "obvious
parts", not "just the scaffolding". The entire value of this skill is that no
implementation code exists until the user has chosen, and a session that pre-builds its
favourite has skipped the step while appearing to follow it.

## After the pick

Once the user chooses:

- Build the real thing in the real tree, now under the normal TDD rule.
- Treat the chosen mockup as the spec. When you're done, screenshot the real
  implementation the same way and compare it against that mockup — this is where the
  ordinary screenshot-iterate loop takes over.
- Leave `.frontend-preview/<slug>/` alone until the work merges; it's the reference.
  It's ignored globally, so it never dirties `git status`.

If the user says "none of these", you learned the direction is wrong for the price of
some throwaway HTML. That's the skill working, not failing. Ask what's off and go again.
