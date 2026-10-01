# Preview routes, rung by rung

Where a preview mounts, per framework, and how it comes back out. Shared by
[`frontend-preview`](../SKILL.md) and
[`render-component`](../../render-component/SKILL.md), which adds what goes *inside* the
mount point in [`harness.md`](../../render-component/references/harness.md).

Read the convention, your own framework's recipe under rung 2, and "Removal"; skip the
other frameworks' recipes. Rungs 3 and 4 at the end are `frontend-preview` only —
`render-component` always mounts in the real app.

Verified end to end on Vite + React 19, Vite + Vue 3, Next.js 16 (app and pages routers),
SvelteKit 2 / Svelte 5, Astro 7, Nuxt 4 and React Router 7: the mount point, the dev
guard, the production build, and the removal command. Each table row below says which.

## Everything lives in `preview__/`

One directory at the **repo root**. Harness files, fixtures, options, the registry, a
preview-only dev config — all of it:

```
preview__/
  index.html          Vite only: the preview's own page
  main.jsx            mounts the chosen preview
  registry.js         { 'order-summary': … } — a static map, never a dynamic import
  order-summary.jsx   one file per component or option
```

The registry is a plain object in a `.js` file everywhere except SvelteKit, where it is a
`registry.svelte` component because a Svelte route hands it a prop. Vite skips it: the
map lives in `main.jsx`, which is already the folder's own entry.

Removal is deleting that directory. Three properties decide the convention, and each one
is why a plausible alternative is wrong:

**Root, not `src/`.** Vite's dev server serves HTML relative to its root, so
`preview__/index.html` has to sit there to be served at `/preview__/`. The root is also
the one place every framework reaches with a single alias — `@/preview__` in Next,
`~~/preview__` in Nuxt, `../preview__` elsewhere — and it keeps the folder out of the
app's own source tree, where it would be type-checked, linted and glob-swept along with
real code.

**`preview__`, visible, trailing underscores.** One greppable token that announces itself
in `ls` and in a review. A *leading* underscore means "private, not a route" in Next.js,
so `__preview` 404s — measured, which is why the convention reads backwards.

**Gitignored on this machine.** This dotfiles repo's `gitignore_global` carries
`preview__*`, matching any file or directory of that name at any depth, so the harness
stays out of `git status` and out of `git add -A`.

That is a machine-local setting — `core.excludesFile`, not anything in the repo — so it
holds here and nowhere else. On a CI checkout, a dev container or a second machine, the
same files are plain untracked files that `git add -A` will happily commit. So the
removal below is the thing that keeps them out of a commit, and the `find` is the leak
detector; `git status` no longer is, on either kind of machine. `git clean -nd` will not
list them here either — that needs `-ndx`.

This bites hardest on rung 4, which dumps a live page's serialized DOM into the folder:
tokens, emails and the whole hydration payload, in a file git has stopped mentioning.

## What each framework forces outside the folder

A filesystem router only looks in its own routes directory, so those frameworks need one
**thin loader** there: a re-export and a guard, no fixtures and no logic. Every path it
creates is also named `preview__`, which is what keeps removal to one command.

| Framework | Outside `preview__/` | Preview in the production build | Dev guard |
|---|---|---|---|
| Vite — React, Vue (Svelte by extension); router or not; backend-served | **nothing** | no — never a build input | `import.meta.env.DEV` in `preview__/main.*` |
| Astro | `src/pages/preview__/[option].astro` | no — the route is not emitted | `getStaticPaths()` returns `[]` |
| Next.js, app router | `app/<group>/preview__/[option]/page.jsx` | yes, fixture included | `notFound()` |
| Next.js, pages router | `pages/preview__/[option].jsx` | yes, fixture included | `getServerSideProps` → `{ notFound: true }` |
| SvelteKit | `src/routes/preview__/[option]/` (2 files) | yes, fixture included | `error(404)` in `+page.js` |
| Nuxt | `app/pages/preview__/[option].vue` | route yes, fixture tree-shaken | `createError({ statusCode: 404 })` |
| React Router 7, config routes | 2 lines in `app/routes.ts` | yes, fixture included | `throw new Response(null, { status: 404 })` in the loader |

Five of the seven compile the preview route into a production build — four of them with
the fixture string inside it — so the guard is what stands between a forgotten preview
and a live route. All five were production-built and then served: each returned 404 for
the preview URL and 200 for the app's own page. On Vite and Astro nothing reaches the
build at all. Keep the Vite guard anyway: it costs one line and survives a project that
later globs its HTML entries.

**Map options statically.** `import(\`./preview__/${param}\`)` lets any visitor flip a
shipped app into preview mode and drags every option into the bundle. A plain object
keyed by name does the same job with a bounded, reviewable set.

## Removal

### Look first

`preview__*` is a **prefix match** and the next step deletes, so read the list before
running it:

```bash
cd "$(git rev-parse --show-toplevel)"
find . -name 'preview__*' -not -path '*/node_modules/*' -not -path './.git/*' -prune -print
```

The `cd` is load-bearing. The command has no root of its own, so from the wrong
directory it sweeps whatever is below that one — and inside a worktree
`--show-toplevel` is that worktree, which is exactly the scope you want. Run from a
checkout that keeps its worktrees inside itself, it would reach a sibling session's live
harness.

If the list holds a path you did not create — a repo that genuinely keeps a
`preview__gallery/` — delete your own paths by name instead of sweeping. The ignore rule
below means git holds no copy of anything in that list.

### Then one command

```bash
find . -name 'preview__*' -not -path '*/node_modules/*' -not -path './.git/*' -prune -exec rm -rf {} +
```

It takes the root folder, every framework's loader directory, and any `preview__`-named
file left elsewhere. Run in all seven proof apps, it left exactly one thing behind: the
React Router import line, which is the next check's job.

### Done means these three come back clean

1. **The listing above prints nothing.** It is what deletes, because the harness carries
   `preview__` in its **path**, not its contents — a grep alone reports a clean tree
   while `preview__/` is still sitting there.
2. **No hit for the token inside files that were already there**, and `git diff` shows
   no preview edit left in one:
   ```bash
   grep -rn 'preview__' --exclude-dir={node_modules,.git,.next,dist,build,.svelte-kit,.output} .
   git diff --stat
   ```
   This is what catches React Router's two lines in `app/routes.ts` and Nuxt's
   `<NuxtPage />`, both edits to tracked files. Delete them by hand; they are the only
   preview work `git status` can see.
3. **No hit for your fixture string in build output**, after a rebuild:
   ```bash
   grep -rl 'AC-10428' .next/ dist/ build/ .svelte-kit/ .output/ 2>/dev/null
   ```
   Stale output keeps the fixture under hashed filenames no path search can see —
   measured: `.next/static/chunks/10i9qvxhe4x9w.js` still held it after a clean delete.
   A hit on stale output clears on `npm run build`; a hit *after* rebuilding means a
   preview file is still wired into the app, so go back to check 1.

## Rung 2 — a throwaway route in the real app

The goal is a URL the dev server already serves, rendering your option through the real
layout, providers and CSS.

### Vite — React and Vue verified; Svelte by extension

Give the preview **its own HTML entry** inside the folder. Vite's dev server serves any
HTML under its root, so `/preview__/` just works, and `vite build` only ever reads the
root `index.html` — the folder is not in the production graph at all. Nothing existing is
edited, so there is no entry-point branch to forget.

`preview__/index.html`:

```html
<!doctype html>
<html lang="en">
  <head><meta charset="UTF-8" /><title>preview__</title></head>
  <body>
    <div id="root"></div>
    <script type="module" src="/preview__/main.jsx"></script>
  </body>
</html>
```

`preview__/main.jsx`:

```jsx
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import '../src/index.css'
import OptionA from './option-a'

const options = { 'option-a': OptionA }
const requested = new URLSearchParams(location.search).get('p')
const Option = import.meta.env.DEV ? options[requested] : undefined

createRoot(document.getElementById('root')).render(
  <StrictMode>{Option ? <Option /> : <p>unknown preview</p>}</StrictMode>,
)
```

Visit `/preview__/?p=option-a` — the query form, because this recipe serves one page
rather than a route per option. The routed frameworks below use `/preview__/option-a`
instead.

Four things decide whether it looks like the app:

- **Copy the mount element id from the app's own `index.html`.** React scaffolds use
  `root`, Vue scaffolds use `app`, and a mismatch between the div here and the selector
  in `main.*` renders a blank page — the exit-4 failure this file keeps warning about,
  from a one-word difference.
- **Import the entry's CSS exactly as `src/main.jsx` does**, by relative path. That
  import is what pulls in the compiled Tailwind; miss it and you have a drawing.
- **Render the option as an element** (`<Option />`), not by calling it (`Option()`) —
  calling it breaks every hook and the page comes back empty, which reads like a broken
  rung rather than a one-character bug.
- **A router is only needed if the component reads one.** A preview entry mounts its own
  tree, so there is no app router to add a route to; give the component a memory router
  instead, per `harness.md`.

Vue is the same shape with `createApp` in `preview__/main.js` and `<div id="app">` in the
HTML; `harness.md` has it, including the plugins a fresh app instance starts without.

### Vite whose HTML a backend serves (verified)

Common in Rails/Phoenix/Django apps with a React front end: the dev server has no page of
its own, the build input is `/src/index.tsx`, and the real HTML comes from the backend
with server-injected props. The recipe above already covers it — the preview's HTML entry
is the page the dev server was missing — but it needs **its own config**, which also
lives in the folder:

`preview__/vite.config.js`:

```js
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  root: new URL('..', import.meta.url).pathname,   // the repo root, so /src/… resolves
  plugins: [react()],
  server: {
    port: 3111,
    strictPort: true,
    host: '127.0.0.1',
    // The root is the whole repo, and Vite's dev server serves what is under its root.
    // Without this, `config/master.key`, `credentials.yml.enc` and .git are all one
    // HTTP GET away — and these are exactly the stacks that keep them in-tree.
    fs: { strict: true, allow: ['src', 'preview__', 'node_modules'] },
  },
})
```

Run it with `npx vite --config preview__/vite.config.js` — verified serving
`/preview__/` while the app's own dev server kept its port. Four things decide whether it
works:

- **Copy the provider stack from the test harness, not from the app entry.** A repo with
  component tests already has a wrapper that mounts one component with the real theme,
  icons, toasts, router and Apollo client and *without* the auth bootstrap — already
  debugged. Find it (`renderWithProviders`, `TestProviders`, `renderWithTheme`) and mirror it.
- **Mirror the app's pipeline, minus the dev-only plugins.** Same Tailwind, JSX, SVG,
  tsconfig-paths and Node-shim plugins; drop the type-checker and bundle-visualizer,
  which only produce overlay noise. The repo's test config is usually that list already.
- **Proxy what the backend serves.** Icon sprites, fonts and `/graphql` come from the
  backend's origin; `server.proxy` keeps them same-origin so nothing is silently blocked.
  Verify with `requestfailed` during capture, not by eye.
- **Pick a free port.** `strictPort` makes a collision a hard failure, and the app's own
  dev server usually holds the obvious one. Take something far away (3111) and bump on
  the first collision rather than debugging it.

Ambient contexts that are heavy to construct (a project/filter/router chain behind a
`useProject`/`useTabs` hook) don't need their real providers if the preview never clicks
them. A `resolveId` plugin **in the preview config only** swaps the hook module for a
stub, which keeps the stub out of the app config and out of the component:

```ts
{
  name: "preview__:stub-contexts",
  enforce: "pre",
  async resolveId(source, importer, options) {
    if (!importer || importer.includes("/preview__/")) return null
    const resolved = await this.resolve(source, importer, { ...options, skipSelf: true })
    if (resolved?.id.includes("/hooks/useOutreachAnalytics.ts"))
      return this.resolve("/preview__/stubs.ts", importer, { ...options, skipSelf: true })
    return null
  },
}
```

Match on the **resolved** id, not the import specifier — the component imports these by
relative path, which a plain `resolve.alias` never sees. Stub only the ambient contexts;
anything the change itself touches must stay real, and say so on the artifact.

In a fresh worktree, `node_modules` doesn't exist. Install before you wonder why `vite`
isn't found.

### Next.js, app router (verified)

The loader inherits `app/layout.jsx` — the fonts, the providers, the global CSS — for
free, which is the entire point.

`app/preview__/[option]/page.jsx`, the whole file:

```jsx
export { default } from '@/preview__/next-page'
```

`preview__/next-page.jsx` carries the guard and the map:

```jsx
import { notFound } from 'next/navigation'
import PreviewOrderSummary from './order-summary'

const previews = { 'order-summary': PreviewOrderSummary }

export default async function PreviewPage({ params }) {
  if (process.env.NODE_ENV !== 'development') notFound()
  const Preview = previews[(await params).option]
  if (!Preview) notFound()
  return <Preview />
}
```

A route group with its own layout (`app/(dashboard)/layout.jsx`) is **not** inherited
from the root. If the surface lives in one, put the loader inside that group —
`app/(dashboard)/preview__/[option]/page.jsx` — or the picture loses the sidebar, the
container width and whatever else that layout supplies. Verified both ways: in the group,
the sidebar renders around the preview.

Without the `@/` alias, the re-export is a relative path, which is depth-sensitive: from
inside a route group it is `'../../../../preview__/next-page'`.

`NODE_ENV === 'development'` is true wherever `next dev` runs, which includes a review
deploy or a dev container on a reachable host. If this project has one, add a second
condition that deploy does not set — `&& process.env.ENABLE_PREVIEW === '1'` — so the
route needs an explicit opt-in rather than just a dev build. The same applies to every
guard in the table.

### Next.js, pages router (verified)

```jsx
// pages/preview__/[option].jsx — the whole file
export { default } from '@/preview__/pages-page'

export function getServerSideProps() {
  if (process.env.NODE_ENV !== 'development') return { notFound: true }
  return { props: {} }
}
```

**Write `getServerSideProps` out in the loader; never re-export it.** Measured: with
`export { default, getServerSideProps } from '@/preview__/pages-page'`, the page
server-renders and then never hydrates. The component sits at its loading state forever,
the console is silent, and the capture is a perfectly valid PNG of a skeleton — the
single most expensive way this recipe can fail. Read `option` from `useRouter().query`
inside the folder instead of passing it through props.

The pages router inherits `_app.jsx`, which is where the global CSS and providers live.
In an app-router project with no `_app.jsx`, a pages-router preview gets no global CSS at
all — use the app router there.

### Astro (verified)

`src/pages/preview__/[option].astro`, the whole file:

```astro
---
import Base from '../../layouts/Base.astro'
import { previews } from '../../../preview__/registry.js'

export function getStaticPaths() {
  if (!import.meta.env.DEV) return []
  return Object.keys(previews).map((option) => ({ params: { option } }))
}

if (!import.meta.env.DEV) return new Response(null, { status: 404 })
const Preview = previews[Astro.params.option]
---
<Base><Preview /></Base>
```

A dynamic route in Astro's **static** output must export `getStaticPaths`, so the guard
and the route table are the same function — returning `[]` means the page is never
emitted, which is what was verified here. `getStaticPaths` is not consulted for a route
that is server-rendered, though, so an adapter with `output: 'server'` or a page with
`prerender = false` would leave the route live. The second line guards that case and
costs nothing in a static build, where it is never reached. Set the same layout the real page uses. Astro ships no client JS by
default; if the surface depends on an island, give it the same `client:` directive the
real page gives it.

### SvelteKit (verified)

Two files under `src/routes/preview__/[option]/`, both thin:

```js
// +page.js
import { dev } from '$app/environment'
import { error } from '@sveltejs/kit'

export function load({ params }) {
  if (!dev) error(404)
  return { option: params.option }
}
```

```svelte
<!-- +page.svelte -->
<script>
  import Registry from '../../../../preview__/registry.svelte'
  let { data } = $props()
</script>
<Registry option={data.option} />
```

Svelte 5 is runes-only in a fresh project: `let { x } = $props()`, not `export let x`,
and a dynamic component is `<Preview />` with a capitalised variable, not
`<svelte:component>`. Both old forms are hard compile errors, which at least fail loudly.

### Nuxt (verified)

`app/pages/preview__/[option].vue`, the whole file:

```vue
<script setup>
import { previews } from '~~/preview__/registry.js'

if (!import.meta.dev) throw createError({ statusCode: 404 })
const Preview = previews[useRoute().params.option]
if (!Preview) throw createError({ statusCode: 404 })
</script>
<template><component :is="Preview" /></template>
```

`~~` is the rootDir alias — `~` points at `app/`, so it will not reach the folder. Nuxt's
auto-imported components resolve inside `preview__/*.vue` even though it sits outside
`app/`, so the harness files need no import for them.

An app with no `pages/` directory at all renders `app.vue` directly; adding the first
page also means adding `<NuxtPage />` there, which is an edit to an existing file. Say so
and remove it at cleanup.

### React Router 7 / Remix (verified)

Routes are configured, not discovered, so this is the one framework that needs an edit to
a file that was already there — two lines. Only the import carries the token, so the grep
points at line one and **the spread on the export line goes with it**; measured, that is
the single thing the removal command leaves behind in seven proof apps:

```ts
// app/routes.ts
import { previewRoutes } from "../preview__/routes";

export default [index("routes/home.tsx"), ...previewRoutes] satisfies RouteConfig;
```

The route module itself stays in the folder — `route()` accepts a path outside `app/`:

```ts
// preview__/routes.ts
import { route } from '@react-router/dev/routes'
export const previewRoutes = [route('preview__/:option', '../preview__/rr-route.tsx')]
```

Guard in that module's `loader` with `throw new Response(null, { status: 404 })`. A
project using `@react-router/fs-routes` instead gets file discovery back: drop
`app/routes/preview__.$option.tsx` as the loader and leave `app/routes.ts` alone.

### Plain multi-page app (Rails, Django, Laravel, Phoenix) — not verified here

Render a real template through the real view layer rather than writing HTML by hand — the
layout is where the stylesheet tag lives. Add one route inside the framework's
development-only block, pointing at a template under `preview__/`. These stacks serve a
genuine static stylesheet, so rung 3 is close to free and usually the better trade.

When one of these backends serves the HTML but a JS bundler owns the components, the
surface belongs to the bundler — use the backend-served Vite recipe above.

## Rung 3 — standalone HTML, the app's real stylesheet

One HTML file per option **in `preview__/`**, markup in the app's real class names, and a
`<link>` to the stylesheet the dev server is actually serving. The whole trick is getting
that URL right.

**Vite dev serves CSS as a JavaScript module.** `/src/index.css` returns JS that injects
styles at runtime — link that and your page gets no styling at all. Append `?direct` for
the real compiled CSS:

```html
<link rel="stylesheet" href="http://localhost:5173/src/index.css?direct">
```

Check before you build on it: `curl -s 'http://localhost:5173/src/index.css?direct' | head -5`
must show CSS, not `import`.

For the others:

- **Next.js dev** serves CSS under `/_next/static/css/*.css`. Find the real filename in
  the page's own HTML: `curl -s http://localhost:3000/ | grep -o '/_next/static/css/[^"]*'`.
- **A built app** (`npm run build`) writes a plain hashed `.css` into `dist/` or
  `.next/static/`, the most reliable source of all. If the dev server fights you, build
  once and link the built file.
- **Rails / Django / Laravel / Phoenix** serve a real stylesheet path already; read it out
  of the rendered page's `<head>`.

Whichever you use, confirm it with `curl` before writing three options against it.

### Webfonts need a `<link>`, not an `@import`

Measured, and it will bite you: headless Chrome renders a webfont reached by a `<link
rel="stylesheet">` in the document head, and **does not** render one reached through an
`@import` inside a CSS file. The page captures cleanly in a fallback serif, at every
`--wait` value, so `--stable` sees a settled page and passes it.

So put the font link in the head yourself:

```html
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Fraunces:wght@700&display=block">
```

Use `display=block` rather than `swap`: `swap` renders the fallback first, which is
exactly what you don't want in a screenshot. Then compare the heading in your capture
against the before shot — if one is in Times and the other isn't, the font didn't land.

This does not affect rung 2, where the app loads its own fonts however it normally does.

## Rung 4 — starting from the real DOM

When the change is a small edit to a dense page, the fastest honest mockup is the live
page's own markup:

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless --disable-gpu --dump-dom --virtual-time-budget=3000 \
  "http://localhost:3000/settings/billing" > preview__/option-a.html
```

Then edit only the part you're changing, and add the rung 3 stylesheet link to its head —
`--dump-dom` gives you the markup, not the styles. Relative asset URLs break in a local
file, so add `<base href="http://localhost:3000/">` near the top of the head.

### Dump from a throwaway account, never a real session

A serialized DOM carries far more than what's on screen: the signed-in user's name and
email, CSRF tokens, partial card numbers on a billing page, and the whole hydration
payload (`__NEXT_DATA__`, `window.__remixContext`, the Nuxt payload) — which is the full
API response for that surface, including fields the UI never renders.

The skill **publishes screenshots of this file to a web page**. So:

- Dump from seeded dev data, a test account, or the logged-out state. Never a dump of
  real customer data, and never a production host.
- Before publishing, scan the file for what you didn't mean to ship:
  `grep -niE 'email|token|csrf|session|@[a-z0-9.-]+\.[a-z]{2,}|[0-9]{4}[- ]?[0-9]{4}' file.html`
  Replace real names, addresses and numbers with equally-long fake ones — equally long,
  or you've changed the layout you're trying to preview.
- The dump lives in `preview__/`, which is gitignored and deleted with everything else.

The Chrome DevTools MCP does this more cleanly when it's connected, and can wait on
`document.fonts.ready` besides. Treat it as an accelerator, never a dependency — it is
frequently not up, and this bash path is what always works.
