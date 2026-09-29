# The harness — what you wrap the component in

Where the harness mounts is per-framework and lives in
[`../../frontend-preview/references/preview-routes.md`](../../frontend-preview/references/preview-routes.md).
This file is the other half: what goes *inside* that mount point so a component written
to run behind a login renders with nothing behind it.

Verified end to end on Vite + React 19 and Vite + Vue 3 (+ vue-router): the harness file,
the entry-point branch, faked context, a faked router, a stubbed fetch, the capture, and
the production build. The Next.js note at the end reuses the verified route from
`preview-routes.md`; its fakes follow the same shape but were not re-measured.

## The shape

One file per component under `preview__/`, holding three things and nothing else:

1. a fixture — literal, in the file, shaped like real data;
2. the fakes — providers, router, stubbed network;
3. the component, rendered as an element with the fixture as props.

Props go in the file as real JavaScript, not through a query string. A query string
cannot carry a function, a date, a React element or a slot, and the encoding is one more
thing to get wrong between you and the picture. Editing the file and reshooting is the
variant loop.

## Keep module scope clean, or the fixture ships

The one trap that survives the dev guard: a **side effect at module scope keeps the whole
harness file in the production bundle**. The bundler cannot drop a module that does
something on import, even when every export is tree-shaken away and the guard means
nothing ever calls it.

Measured on Vite 8, production builds of both proof apps:

| Harness file does | In `dist/` |
|---|---|
| `globalThis.fetch = …` at module scope (React) | the whole module — **fixture strings and all** |
| the same assignment inside the component body | nothing |
| `import './preview.css'` at module scope (React) | the CSS only; the fixture still dropped |
| a `<style scoped>` block in the preview SFC (Vue) | nothing |

So: fixture and stubs go **inside** the component body or `<script setup>`. Module scope
holds imports.

That table is four measurements on one bundler, not a law. Webpack-based builds (Next.js,
CRA) keep modules by default unless the app sets `"sideEffects": false`, and nobody has
measured this skill's harness there. So **check rather than trust**, once, before you call
the cleanup done:

```bash
npm run build && grep -rl "AC-10428" dist/ .next/ 2>/dev/null   # your fixture string
```

A hit means the harness is in the shipped bundle. That is what step 5 deletes anyway — the
grep is how you find out the guard alone was not enough on this project.

## Vite + React (verified)

`src/preview__/order-summary.jsx`:

```jsx
import OrderSummary from '../app/OrderSummary'
import { AuthContext } from '../app/auth'

export default function PreviewOrderSummary() {
  const order = {
    reference: 'AC-10428',
    lines: [
      { sku: 'CHR-01', name: 'Aeron remastered, size B', qty: 1, unitPrice: 1395 },
      { sku: 'MAT-02', name: 'Anti-fatigue mat', qty: 2, unitPrice: 79 },
    ],
  }

  // The component's useOrder hook fetches. Stubbed here, inside the body.
  globalThis.fetch = async () =>
    new Response(JSON.stringify(order), { headers: { 'content-type': 'application/json' } })

  return (
    <AuthContext.Provider value={{ user: { name: 'Dana Whitfield' } }}>
      <OrderSummary orderId="ord_1042" />
    </AuthContext.Provider>
  )
}
```

`src/main.jsx` — one branch, the existing render path untouched as the `else`:

```jsx
import PreviewOrderSummary from './preview__/order-summary'

const previews = { 'order-summary': PreviewOrderSummary }
const requested = new URLSearchParams(location.search).get('preview__')
const Preview = import.meta.env.DEV ? previews[requested] : undefined

createRoot(document.getElementById('root')).render(
  <StrictMode>{Preview ? <Preview /> : <App />}</StrictMode>,
)
```

Visit `/?preview__=order-summary`. Render the preview as an element (`<Preview />`), not
by calling it (`Preview()`) — calling it breaks every hook inside and the page comes back
empty, which reads like a broken harness rather than a one-character bug.

## Vite + Vue (verified)

Vue's providers and plugins attach to the **app instance**, not to a wrapper element, so
the harness needs a mount function rather than a wrapper component.

That is a deliberate departure from `preview-routes.md`, which says to add a route to the
existing router instead of branching in the entry. That advice is right when the goal is
the real layout around a page. Here the goal is control over what the component is handed,
and a fresh app instance is the only place you get it.

The cost of a fresh instance is that **it starts empty**. Read `main.js` first and re-apply
what it applies — Pinia, i18n, global components, directives, `app.config` — before
`app.mount`. Miss the i18n plugin and every string renders as its own translation key,
which looks exactly like a broken component.

`src/preview__/order-summary.vue` — fixture and stub, inside `<script setup>`, which runs
per instance rather than per module:

```vue
<script setup>
import OrderSummary from '../app/OrderSummary.vue'

const order = {
  reference: 'AC-10428',
  lines: [{ sku: 'CHR-01', name: 'Aeron remastered, size B', qty: 1, unitPrice: 1395 }],
}

globalThis.fetch = async () =>
  new Response(JSON.stringify(order), { headers: { 'content-type': 'application/json' } })
</script>

<template>
  <OrderSummary order-id="ord_1042" />
</template>
```

`src/preview__/mount.js` — everything the running app would have supplied:

```js
import { createApp } from 'vue'
import { createRouter, createMemoryHistory } from 'vue-router'
import { AUTH } from '../app/auth'
import OrderSummaryPreview from './order-summary.vue'

const previews = { 'order-summary': OrderSummaryPreview }

export async function mountPreview(name) {
  const app = createApp(previews[name])

  app.provide(AUTH, { user: { name: 'Dana Whitfield' } })

  // With no router installed useRoute() returns undefined and the component
  // throws on the first .params read. Register the component's REAL path
  // pattern: params are named by the pattern, not by the URL you push.
  const router = createRouter({
    history: createMemoryHistory(),
    routes: [{ path: '/orders/:orderId', component: { render: () => null } }],
  })
  app.use(router)
  await router.push('/orders/ord_1042?from=checkout')
  await router.isReady()

  app.mount('#app')
}
```

`src/main.js`:

```js
import { mountPreview } from './preview__/mount'

const requested = new URLSearchParams(location.search).get('preview__')

if (import.meta.env.DEV && requested) {
  mountPreview(requested)
} else {
  createApp(App).mount('#app')
}
```

Import `mount.js` statically. A top-level `await import(...)` in the entry works in dev
and then constrains the production build target, which is a strange thing to leave behind
in a file that was already there.

## Faking what the component reaches for

| It uses | Give it |
|---|---|
| `useContext(X)` / a `useX` wrapper | `<X.Provider value={…}>` around the component |
| `inject(KEY)` / `useX` on top of it | `app.provide(KEY, …)` in the mount function |
| `useRouter` / `useRoute` / `useParams` | a memory router carrying the component's **real path pattern** — see below |
| a data hook (`useQuery`, `useOrder`) | stub the transport under it, not the hook: the component keeps its real loading and error paths |
| a store (Redux, Pinia, Zustand) | the store's own test helper if it has one, otherwise a provider around a hand-built initial state |
| `useTranslation` / `useI18n` | the real i18n instance with the real messages — a fake returns the key, and raw keys on screen read as a broken component |

### A memory router needs the real route pattern

**Params are named by the route pattern, not by the URL you push.** A catch-all route is
the tempting shortcut and it silently hands the component nothing: measured on
vue-router 5, pushing `/orders/ord_1042` at `routes: [{ path: '/:rest(.*)' }]` gives
`params: { rest: 'orders/ord_1042' }`, so `route.params.orderId` is `undefined` and the
component throws on the next line — which step 3 then shows you as an exit-4 blank page
you will waste twenty minutes blaming on a provider. With `{ path: '/orders/:orderId' }`
it gives `params: { orderId: 'ord_1042' }`.

Query values are the exception: `?from=checkout` arrives either way.

So copy the pattern out of the app's real route table, and keep a catch-all only for a
component that reads no params at all. React Router is the same shape — `MemoryRouter`
alone gives `params: {}`; the component has to sit inside a matching `<Route>`:

```jsx
<MemoryRouter initialEntries={['/orders/ord_1042']}>
  <Routes><Route path="/orders/:orderId" element={<OrderSummary />} /></Routes>
</MemoryRouter>
```

**Stub the transport, not the hook.** Replacing `globalThis.fetch` for the length of the
preview keeps the component's own fetch-parse-render path intact, so what you photograph
is what the component really does with data. Replacing the hook photographs your
replacement.

### What a `fetch` stub does not cover

Three holes, and each one ends in a real authenticated request when the dev server proxies
`/api` to staging with the developer's cookies:

- **Other transports.** XHR — which is axios's default adapter — plus `sendBeacon`,
  WebSockets and `EventSource` all go straight past it.
- **Timing.** The stub is installed when the component renders. Anything the app entry
  fires at import time — analytics, error reporting, a token refresh — has already gone.
- **Children you did not read.** Step 1 covers the component and its direct imports; a
  grandchild three levels down can call out on mount.

So: if the project runs **MSW**, use its handlers instead of the `fetch` stub — it covers
XHR too and installs before the app boots. If it does not, and the component's tree uses
anything but `fetch`, check what the dev server proxies to before you shoot. A proxy
pointed at a real backend is the case where an un-stubbed call stops being cosmetic.

To photograph a **loading** state, return a promise that never resolves. For an **error**
state, reject, or resolve with a non-ok `Response`.

## Next.js (route verified, fakes by extension)

`app/preview__/[option]/page.jsx` with the `notFound()` guard from `preview-routes.md`.
Providers and hooks are client-side, so the harness file beside it carries `'use client'`
at the top and holds the fixture, the fakes and the component. The route file stays a
server component that picks one harness out of a static map.

A route group with its own layout is not inherited from the root: if the component's real
home is inside `app/(dashboard)/`, put the preview route in that group or the picture
loses the sidebar, the container width and whatever else that layout supplies.

That layout is real code against a real session, so it draws real data around your fake
fixture — the signed-in name, the org, whatever a sidebar lists. Read the whole frame
before the screenshot goes anywhere, per step 3.
