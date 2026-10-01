---
name: frontend-preview
description: "Show what a frontend change looks like, as a published Artifact of real screenshots. Two modes: before implementation, 2-3 design options with a blocking pick; for a change already built, a before/after of what shipped with no pick. Invoke it yourself, unprompted, whenever a task changes what a user sees in a browser and the change cannot be judged by reading the diff — a new page, a redesign, a component, a layout, spacing, colour, a chart, a state that renders differently — before writing any implementation code. Also use when the user asks to see or preview a frontend change they already made, or invokes /frontend-preview. Do not wait to be asked and do not ask permission first. Text-only changes are the exception: copy, a label, a typo, a translation string."
---

# frontend-preview

Before writing a single line of frontend implementation code, show the user what they
have now, what they'd get, and the two or three directions it could go — as pictures,
in one page they can open on a phone. Then **stop** and let them choose.

The point is not to document your plan. It's to make the user's "no, not that one"
cost thirty seconds instead of four hundred lines.

Which means the options have to be **rendered by the real app**, not drawn from memory.
A before-shot is a photograph; a hand-written mockup with invented CSS is a drawing.
Put them side by side and the user reads every difference between photograph and
drawing — missing webfonts, wrong spacing, absent shadows — as *your design being
wrong*. They reject a direction that was fine. Steps 3 and 5 exist to stop that.

## When this runs

Nobody has to ask for it. When the answer to this is yes, run it unprompted, before
you write any implementation code:

> Would a screenshot of the app look different after this change?

That's the whole test. Invoking the skill is how you raise the question — don't ask
the user whether they'd like a preview first, and don't offer one instead of running
one. Borderline counts as yes.

A new page, a redesign, a layout or spacing change, a component, a colour, a chart, a
state that renders differently — yes. A renamed API route, a query optimisation, a
test, a build config — no, even if the word "dashboard" appears in the request. Copy
on its own — yes only when the new words change the shape of the thing, a heading that
now wraps to two lines or a button that outgrows its row.

**Skip it, and say you're skipping it, when:**

- The change is text only — copy, a label, a typo, a translation string, an alt
  attribute — and nothing about the layout moves.
- The change is visually trivial and has exactly one sensible form (bump one
  colour the user already named, revert a known-good commit).
- The user gave you a mock, a Figma frame, or a screenshot to match — the direction is
  already picked. Go implement it.
- The user explicitly says to just build it.
- The user wants to *look at* something that already exists rather than choose how it
  should look — "show me what OrderSummary renders as". Nothing is being decided, so
  there is nothing to block on. That's the `render-component` skill.

Never skip it silently. If you decide it doesn't apply, say so in one line and move on.

## Variant: the change is already built

Sometimes the user wants to *see* a change that already exists — a commit they just made,
work another session shipped, a branch under review. Same machinery, three differences,
and they don't need re-deriving each time:

- **Before** is the surface at the commit before the change (`git show <sha>^:<path>`),
  not an option you invented. Copy that file next to the real one as
  `preview__<Name>Before.tsx` — it has to sit among real source, because that is where
  its relative imports resolve. It carries the token in its name, so the removal command
  takes it along with the folder, provided that command is run from the repo root as
  written. Render both.
- **After** is the current code — one panel per state the change touches, not one per
  design direction. Steps 4's "one option is the smallest change" and the option
  tradeoffs don't apply; drop them.
- **Don't block.** There's nothing to pick. Publish, hand over the URL, and end with
  `finished`, not `needs-decision`.

Everything else — rung choice, real data, reading every PNG back, the artifact — is
unchanged.

## Everything you make here is disposable

Two rules, and the first is the one that matters:

**No implementation code until the user picks.** Not the component they'll probably
want, not the "obvious parts", not the scaffolding. The entire value of this skill is
that nothing real exists until the choice is made.

**Everything you add to the real tree goes in one directory and is deleted before
merge.** Rung 2 below puts a preview route inside the running app, which is the only way
to get the app's real CSS, fonts and providers. That's allowed, under these conditions:

- It lives in `preview__/` at the repo root — a name that announces itself, and the one
  thing the removal command has to find. A framework whose router only reads its own
  directory also needs a thin loader in that directory; which path, per framework, is in
  [`references/preview-routes.md`](references/preview-routes.md).
- It is **guarded to development**, so it is inert if it ever escapes. Most of these
  frameworks compile the preview route into a production build — that reference's table
  says which, and what each guard was measured to do.
- It is **additive only**: the component you are previewing is read, never written.
- It never merges. Delete it after the pick, before you write the real thing.

Do this in a **worktree**, where the tree is already disposable. Working directly in the
user's main checkout, take rung 3 instead, or ask first.

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

## Step 2 — Capture "what we have"

Get the app running and shoot the real current state. **Use the `run` skill** to find or
start the dev server — it already knows how this project launches, and duplicating that
logic here will rot. You need a URL.

Capture with `frontend-preview-shot.sh` (dotfiles-managed, on `PATH` as
`~/.config/bin/frontend-preview-shot.sh`). It drives headless Chrome — no install,
nothing added to the project — and fails loudly when the capture didn't actually work:

```bash
frontend-preview-shot.sh --width 1280 --height 900 --wait 3000 --stable \
  "http://localhost:3000/settings/billing" \
  .frontend-preview/<slug>/shots/before-desktop.png
```

Pass `--stable` on every capture of the running app. It shoots again at double the wait
and requires the two to agree, which is how you find out the page was still pulling in
webfonts or still showing a skeleton. It cannot tell you about a resource that *never*
loads — that renders identically at every wait, so it settles, looking wrong.

**Check the exit code every time.** Each failure is distinct and tells you what to do:

| Exit | Meaning | What to do |
|---|---|---|
| 0 | Captured and validated | Go on |
| 2 | Browser wrote nothing | Is the dev server actually serving that URL? |
| 3 | No usable browser | Install Chrome, or set `FRONTEND_PREVIEW_BROWSER` |
| 4 | **Capture looks blank** | Raise `--wait`; the page probably hadn't rendered |
| 5 | Output isn't a PNG | Something is badly wrong; report it, don't retry blindly |
| 6 | **Page never settled** | Still loading at double the wait — raise `--wait`, or pick a state that finishes |
| 7 | **Capture looks unstyled** | Step 5's check; the CSS didn't reach the page |
| 64 | Bad arguments | Read the usage |

Exits 4, 6 and 7 are what earn the script: each is a *valid PNG* that looks like success
everywhere except a human's eyes. Shipping one makes the user think the design is broken
rather than the capture. They are heuristics, so they can be wrong in both directions —
pass `--allow-blank` for a state that genuinely is empty, and **still read every PNG back
yourself** before building the artifact. The script catches the obvious catastrophes;
your eyes catch a half-rendered page, which it cannot.

Two more things worth knowing:

- Chrome prints alarming `ERROR:` lines about display links and task policies on macOS
  and still succeeds. The script judges by the file, not the stderr. So should you.
- Captures are viewport-sized, not full-page. For content below the fold pass a taller
  `--height` rather than hunting for a full-page flag — headless Chrome has none.

**When the state needs an interaction, drive Playwright instead.** The script shoots a
page at rest; it cannot hover, focus, open a tooltip or a menu. If the surface looks
wrong at rest — icons greyed until the row is hovered, a control that only shows its
label on focus — a resting-only shot reads as broken, and you need both frames. Most
frontend repos already have Playwright installed, so a ~30-line script is cheaper than
faking the state in CSS:

```js
import { chromium } from "playwright"
const page = await (await chromium.launch()).newPage({
  viewport: { width: 1280, height: 900 }, deviceScaleFactor: 2,
})
page.on("pageerror", e => problems.push(e.message))
page.on("requestfailed", r => problems.push(r.url()))   // catches a stylesheet or icon that never loaded
await page.goto(url, { waitUntil: "networkidle" })
await panel.screenshot({ path: "...-resting.png" })     // locator.screenshot crops to one panel
await icon.hover()
await panel.screenshot({ path: "...-hovered.png" })
```

Run it from the project directory so `playwright` resolves, and read the collected
`pageerror` / `requestfailed` lines — they catch the unstyled-page case earlier than the
`--like` check does. An element screenshot clips overlays at the element's edge, so give
the preview stage enough padding for a tooltip to land inside it. Never fake a hover with
a CSS override in the preview page: the component's own `:hover` rules, and the
`!important` ones that deliberately survive hover, are exactly what you're checking.

**If the surface doesn't exist yet** — a brand-new page — do not fake a "before". Render
an explicit `Nothing here yet — this surface is new` panel in that slot on the final
page. An invented before-state is worse than an empty one, because the user will believe it.

## Step 3 — Pick your rung

Options must be rendered *through the project's own CSS pipeline*. Reimplementing the
design system from memory loses the compiled utility classes, the component library's
stylesheet, webfonts, the theme class, preflight and container widths — all at once,
which is what makes a mockup read as broken.

So take the **highest rung this project supports**, and drop only when the one above is
genuinely unavailable. Framework-by-framework recipes and the traps in each are in
[`references/preview-routes.md`](references/preview-routes.md) — read it before you
build rung 2, 3 or 4. It also carries the `preview__/` convention every recipe follows,
and the removal command.

1. **Storybook or an existing component sandbox.** If the project already runs one, a
   new story is the cheapest honest render there is, and nothing about the app changes.
   Best when the change is one component.
2. **A throwaway route in the real app** — `/preview__/option-a` on a routed framework,
   `/preview__/?p=option-a` on plain Vite — importing the real layout, providers, CSS
   and components. Real Tailwind build, real fonts, real tokens, no guessing. This is
   the default for anything page-shaped. Needs a worktree.
3. **Standalone HTML that links the app's real stylesheet.** `<link rel="stylesheet"
   href="http://localhost:3000/...">` pointed at the dev server's compiled CSS, with
   markup written in the app's real class names. Use when the app can't easily mount an
   extra route, or you're not in a worktree.
4. **Start from the real DOM.** Dump the live page's `outerHTML` into the preview file
   and edit *that*, so the mockup inherits exact structure and classes and the only
   visual difference is your change. Good for a small edit to a dense existing page —
   combine it with rung 3 for the stylesheet. Dump from seeded dev data or a test
   account: a serialized DOM carries tokens, emails and the whole hydration payload,
   and step 6 publishes a picture of it.
5. **Invented CSS from harvested tokens.** Last resort. Read the real design tokens,
   Tailwind config, font stack, spacing and radius scales out of the repo rather than
   inventing them — and **label the artifact "visual approximation"**, so the user knows
   the pixels are indicative, not accurate.

Say on the artifact which rung you used. It tells the user how much to trust the pixels.

## Step 4 — Build the options

Write the options at the rung you chose. Three rules decide whether they're useful:

**Real data, from a named source.** Fake data that looks nothing like real data hides
exactly the layout problems the user needs to see — long names, empty fields, big
numbers, six-item lists. In order of preference, pull it from:

1. The project's own fixtures, seeds, factories, or MSW/mock handlers.
2. The dev server's real API response for that surface (`curl` it).
3. The text already on screen — the before capture is of a real page; reuse its actual
   strings.

Say in one line where the data came from. Never `Lorem ipsum`, never `Item 1 / Item 2`.

**One option is always the smallest change that solves the problem.** Label it plainly.
The user must be able to choose boring on purpose — without that option present, this
step quietly becomes a redesign pitch.

**Options are different directions, not three shades of one idea.** Two options that
differ only in padding waste the user's attention; say "there's only one sensible
direction here" and show one, rather than padding the count. For each, write one sentence
on what it trades away — more code, a new dependency, a slower page, a pattern the
codebase doesn't have yet. An option list with no downsides is a sales pitch.

**Name what each option does surface by surface.** A page is usually several things the
user could decide separately — a picker, a filter bar, the table itself. Keep the options
whole, since each one is a coherent point of view and a parts bin is not, but list the
surfaces by name on every card so "A, but B's filter bar" is something the user can say
precisely instead of describing it in prose. Don't offer a per-surface menu; one page,
one pick, with mixing available if they want it.

## Step 5 — Render the options

Same tool as step 2. Shoot every option at the **same width** as the before capture — a
comparison between images of different widths is not a comparison, and the user reads the
size difference as a design difference.

Pass `--like` with the before capture. It compares the two for shared palette: the canvas
colour and how much of the viewport one flat colour covers. A page that rendered without
its stylesheet is a dense, valid, entirely plausible PNG that every other check passes,
and this is what catches it:

```bash
for opt in a b; do
  frontend-preview-shot.sh --width 1280 --height 900 --wait 3000 --stable \
    --like .frontend-preview/<slug>/shots/before-desktop.png \
    "http://localhost:3000/preview__/option-$opt" \
    ".frontend-preview/<slug>/shots/option-$opt.png" || exit 1
done
```

That URL is the routed-framework form. On plain Vite the options live on one page:
`http://localhost:5173/preview__/?p=option-$opt`.

Pair each capture with the before shot **at its own viewport** — the mobile options
against the mobile before, not the desktop one. The check reads how much of the viewport
the canvas colour covers, and that legitimately differs between 1280x900 and 390x844, so
crossing them reports a failure that isn't there.

An exit 7 means the CSS did not reach the page — go fix the rung, don't force past it.
An option that deliberately recolours the canvas (a dark-mode direction) trips it too;
that is the one case to look at the PNG and pass `--allow-palette-shift`, so the bypass
is visible in the command rather than decided silently.

Then read every PNG back yourself, and ask the one question the checks can't: **does this
look like it came from the same app as the before shot?** Same fonts, same weights, same
corner radii, same shadows. If the text is in Times, the stylesheet or the font didn't
load — fix it rather than shipping a drawing.

## Step 6 — Publish the artifact

Load the `artifact-design` skill first, then write the comparison page and publish it
with the Artifact tool. Pass the PNGs as supporting files (a published artifact can't
load anything from outside itself, so images must either ride along in the `files` map
or be inlined as `data:` URIs):

```
Artifact(
  file_path: ".frontend-preview/<slug>/preview.html",
  files: {"shots/before-desktop.png": ".frontend-preview/<slug>/shots/before-desktop.png", ...},
  icon: "...",
  description: "..."
)
```

If any option came from rung 4, scan that file before publishing and replace anything
real — names, emails, tokens, card digits — with equally long fake values. Equally long,
or you have changed the layout you are previewing. The reference file has the grep.

The page must carry, in this order:

1. **One sentence on what's being decided.** The user may be opening this cold, hours
   later, from a worktree they've forgotten. No "as discussed".
2. **Before → After, side by side**, at the same width, so the comparison is honest.
3. **One card per option**: screenshot, a plain-language name, what it changes, what it
   costs, and roughly how much work it is — plus, when the page has more than one
   surface worth deciding, a line per surface naming what this option does there.
4. **Your recommendation, with a reason.** Don't hide behind neutrality — you've looked
   at the code, you have a view. One option, one sentence why.
5. **How the options were rendered** — which rung, and where the data came from. One
   line. If you used rung 5, the words "visual approximation" go here.
6. **How to answer**: "reply with A, B, or C" — and make clear they can also say
   "none of these", or mix by surface: "A, but B's filter bar".

Keep it to one screen of scrolling per viewport. This is a decision aid, not a
deliverable.

## Step 7 — Stop

End the turn. Write nothing else.

If you're in a worktree, end with the worktree-status marker (`needs-decision`), with
the Artifact URL both in the body and in the marker's pointer, for example
`Frontend preview ready — pick A, B or C: <artifact URL>`.

In the user's main terminal, just give them the URL and the question.

## After the pick

Once the user chooses:

- **If the answer mixed options, render the combination once before deleting anything.**
  Nobody has seen that page yet, and two options that each work alone can collide. Same
  rung, same width, one shot; show it and carry on unless they object.
- **Delete the preview first**, before the real work starts — the look-first listing,
  the one removal command and the three checks that say it worked are all in
  `preview-routes.md` under "Removal". Run them there rather than from memory: the
  command deletes recursively and has to be anchored first.
- Build the real thing in the real tree, now under the normal TDD rule.
- Treat the chosen mockup as the spec. When you're done, screenshot the real
  implementation the same way and compare it against that mockup — this is where the
  ordinary screenshot-iterate loop takes over.
- Leave `.frontend-preview/<slug>/` alone until the work merges; it's the reference,
  and it is not part of the harness the removal command takes.

If the user says "none of these", you learned the direction is wrong for the price of
some throwaway markup. That's the skill working, not failing. Ask what's off and go again.
