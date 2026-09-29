# Preview routes, rung by rung

Recipes for rungs 2, 3 and 4 of [`SKILL.md`](../SKILL.md): mounting a throwaway preview
route inside the real app, pointing a standalone HTML file at the app's real compiled
stylesheet, and starting from the live page's own DOM.

Verified end to end on Vite + React + Tailwind v4 and on Next.js (app router): the
preview route, the dev-only guard, the linked stylesheet, `--dump-dom`, webfont
behaviour and the unstyled-capture check. The frameworks not marked as verified follow
the same shape — confirm the URL serves before you build three options on top of it.

## The two rules every recipe follows

**Name it `preview__`.** One greppable token, and the trailing underscores keep it out
of trouble: a *leading* underscore means "private, not a route" in Next.js, so
`app/__preview/` 404s in dev and never appears in the build. Measured — that is why the
convention is not `__preview`.

**Guard it to development.** A preview route is a real route: `next build` compiles
`preview__/[option]` into the production route table. One line makes it inert if it ever
escapes, and turns "a merge away from an incident" into "harmless":

```js
if (process.env.NODE_ENV !== 'development') notFound()
```

Verified: with that line, a production build serves `/preview__/option-a` as 404.

**Map options statically.** `import(\`./preview__/${queryParam}\`)` lets any visitor flip
a shipped app into preview mode and drags every option into the production bundle. A
plain object keyed by name does the same job with a bounded, reviewable set.

## Rung 2 — a throwaway route in the real app

The goal is a URL the dev server already serves, rendering your option through the real
layout, providers and CSS. Pick the smallest mount point the framework offers.

### Next.js, app router (verified)

`app/preview__/[option]/page.jsx` inherits `app/layout.jsx` — the fonts, the providers,
the global CSS — for free, which is the entire point.

```jsx
import { notFound } from 'next/navigation'
import OptionA from './option-a'

const options = { 'option-a': OptionA }

export default async function Preview({ params }) {
  if (process.env.NODE_ENV !== 'development') notFound()
  const Option = options[(await params).option]
  return Option ? <Option /> : notFound()
}
```

Put each option beside it as `option-a.jsx`. Visit `/preview__/option-a`.

A route group with its own layout (`app/(dashboard)/layout.jsx`) is *not* inherited from
the root — if the surface lives in one, put the preview route inside that group
(`app/(dashboard)/preview__/...`) or you lose the sidebar, the container width and
whatever else that layout supplies.

### Next.js, pages router

`pages/preview__/[option].jsx`, same shape and the same guard. It inherits `_app.jsx`,
which is where the global CSS and providers live.

### Vite (React, Vue, Svelte) with no router (verified)

There's no route to add, so branch in the entry module on a query parameter. Keep the
existing render path untouched as the `else`, map the options statically, and let the
bundler drop the whole branch from a production build:

```jsx
import OptionA from './preview__/option-a'

const options = { 'option-a': OptionA }
const requested = new URLSearchParams(location.search).get('preview__')
const Option = import.meta.env.DEV ? options[requested] : undefined
const root = createRoot(document.getElementById('root'))

root.render(
  <StrictMode>{Option ? <Option /> : <App />}</StrictMode>
)
```

Visit `/?preview__=option-a`. Render the component as an **element** (`<Option />`), not
by calling it (`Option()`) — calling it breaks every hook it uses and the page renders
nothing, which reads like a broken rung rather than a bug in the harness.

Import the entry's CSS exactly as it already does — that import is what pulls in the
compiled Tailwind.

### Vite with a router

Add a route rather than branching: `/preview__/:option` in the same router instance, so
the option renders inside whatever layout element the real routes render inside. Register
it only when `import.meta.env.DEV`.

### Astro

`src/pages/preview__/[option].astro`. Set the same layout the real page uses, and return
a 404 outside dev:

```astro
---
import Layout from '../../layouts/Base.astro'
if (!import.meta.env.DEV) return Astro.redirect('/404')
const { option } = Astro.params
---
<Layout><!-- option markup --></Layout>
```

Astro ships no client JS by default; if the surface depends on an island, give the
component the same `client:` directive the real page gives it.

### SvelteKit / Nuxt / Remix

File-based routing, same idea — the preview route must sit where it inherits the same
layout as the surface being previewed, and each needs its own dev guard:

- SvelteKit: `src/routes/preview__/[option]/+page.svelte`, inheriting `+layout.svelte`;
  guard in `+page.js` with `if (!import.meta.env.DEV) error(404)`.
- Nuxt: `pages/preview__/[option].vue`, inheriting `app.vue` and `layouts/default.vue`;
  guard with `if (!import.meta.dev) throw createError({ statusCode: 404 })`.
- Remix: `app/routes/preview__.$option.jsx`, inheriting `app/root.jsx`; guard in the
  loader with `if (process.env.NODE_ENV !== 'development') throw new Response(null, { status: 404 })`.

For a nested layout, nest the preview route under the same parent segment.

### Plain multi-page app (Rails, Django, Laravel, Phoenix)

Render a real template through the real view layer rather than writing HTML by hand —
the layout is where the stylesheet tag lives. Add one route inside the framework's
development-only block, and point it at a template that extends the app's base layout.

If wiring a route is heavier than it's worth, rung 3 is close to free here, because
these stacks serve a genuine static stylesheet.

## Rung 3 — standalone HTML, the app's real stylesheet

One HTML file per option, markup in the app's real class names, and a `<link>` to the
stylesheet the dev server is actually serving. The whole trick is getting that URL right.

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
  `.next/static/`, which is the most reliable source of all. If the dev server fights
  you, build once and link the built file.
- **Rails / Django / Laravel / Phoenix** serve a real stylesheet path already; read it
  out of the rendered page's `<head>`.

Whichever you use, confirm it with `curl` before writing three options against it.

### Webfonts need a `<link>`, not an `@import`

Measured, and it will bite you: headless Chrome renders a webfont reached by a `<link
rel="stylesheet">` in the document head, and **does not** render one reached through an
`@import` inside a CSS file. The page captures cleanly in a fallback serif, at every
`--wait` value, so `--stable` sees a settled page and passes it.

So in a rung 3 or rung 5 file, put the font link in the head yourself:

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
mkdir -p .frontend-preview/<slug>
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless --disable-gpu --dump-dom --virtual-time-budget=3000 \
  "http://localhost:3000/settings/billing" > .frontend-preview/<slug>/option-a.html
```

Then edit only the part you're changing, and add the rung 3 stylesheet link to its head
— `--dump-dom` gives you the markup, not the styles. Relative asset URLs break in a
local file, so add `<base href="http://localhost:3000/">` near the top of the head.

### Dump from a throwaway account, never a real session

A serialized DOM carries far more than what's on screen: the signed-in user's name and
email, CSRF tokens, partial card numbers on a billing page, and the whole hydration
payload (`__NEXT_DATA__`, `window.__remixContext`, the Nuxt payload) — which is the full
API response for that surface, including fields the UI never renders.

Step 6 of the skill **publishes screenshots of this file to a web page**. So:

- Dump from seeded dev data, a test account, or the logged-out state. Never a dump of
  real customer data, and never a production host.
- Before publishing, scan the file for what you didn't mean to ship:
  `grep -niE 'email|token|csrf|session|@[a-z0-9.-]+\.[a-z]{2,}|[0-9]{4}[- ]?[0-9]{4}' file.html`
  Replace real names, addresses and numbers with equally-long fake ones — equally long,
  or you've changed the layout you're trying to preview.
- `.frontend-preview/` is globally gitignored, so a dump left there never shows up in a
  review. Delete it when the work merges rather than letting it sit.

The Chrome DevTools MCP does this more cleanly when it's connected, and can wait on
`document.fonts.ready` besides. Treat it as an accelerator, never a dependency — it is
frequently not up, and this bash path is what always works.

## Cleaning up

After the user picks, and before any real code:

```bash
git status --short
grep -rn "preview__" --exclude-dir=node_modules --exclude-dir=.next --exclude-dir=dist .
```

Delete every hit — the route files **and the branch you added to the entry point**, which
is the one that gets forgotten because it lives inside a file that was already there.
`git status` has to come back clean of preview work before you write the real thing.
