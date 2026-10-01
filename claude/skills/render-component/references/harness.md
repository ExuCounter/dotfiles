# The harness — what you wrap the component in

Where the harness mounts, and the one directory it all lives in, is per-framework and
written down once in
[`../../frontend-preview/references/preview-routes.md`](../../frontend-preview/references/preview-routes.md).
Read that first. This file is the other half: what goes *inside* the mount point so a
component written to run behind a login renders with nothing behind it.

Verified end to end on Vite + React 19 and Vite + Vue 3 (+ vue-router): the harness file,
faked context, a faked router, a stubbed fetch, the capture and the production build. The
Next.js, SvelteKit, Astro, Nuxt and React Router mount points are verified in
`preview-routes.md`; their fakes follow the shape below and were not re-measured.

## The shape

One file per component in `preview__/`, holding three things and nothing else:

1. a fixture — literal, in the file, shaped like real data;
2. the fakes — providers, router, stubbed network;
3. the component, rendered as an element with the fixture as props.

Props go in the file as real JavaScript, not through a query string. A query string
cannot carry a function, a date, a React element or a slot, and the encoding is one more
thing to get wrong between you and the picture. Editing the file and reshooting is the
variant loop.

## Vite + React (verified)

`preview__/order-summary.jsx`:

```jsx
import OrderSummary from '../src/app/OrderSummary'
import { AuthContext } from '../src/app/auth'

export default function PreviewOrderSummary() {
  const order = {
    reference: 'AC-10428',
    lines: [
      { sku: 'CHR-01', name: 'Aeron remastered, size B', qty: 1, unitPrice: 1395 },
      { sku: 'MAT-02', name: 'Anti-fatigue mat, 90x60', qty: 2, unitPrice: 79 },
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

`preview__/index.html` and `preview__/main.jsx` are in `preview-routes.md`. Visit
`/preview__/?p=order-summary`.

## Vite + Vue (verified)

Vue's providers and plugins attach to the **app instance**, not to a wrapper element, so
the preview entry does the mounting itself. The cost of a fresh instance is that **it
starts empty**: read `src/main.js` first and re-apply what it applies — Pinia, i18n,
global components, directives, `app.config` — before `app.mount`. Miss the i18n plugin
and every string renders as its own translation key, which looks exactly like a broken
component.

`preview__/order-summary.vue` — fixture and stub inside `<script setup>`, which runs per
instance rather than per module:

```vue
<script setup>
import OrderSummary from '../src/app/OrderSummary.vue'

const order = {
  reference: 'AC-10428',
  lines: [{ sku: 'CHR-01', name: 'Aeron remastered, size B', qty: 1, unitPrice: 1395 }],
}

globalThis.fetch = async () =>
  new Response(JSON.stringify(order), { headers: { 'content-type': 'application/json' } })
</script>

<template>
  <OrderSummary />
</template>
```

`preview__/main.js` — everything the running app would have supplied:

```js
import { createApp } from 'vue'
import { createRouter, createMemoryHistory } from 'vue-router'
import '../src/style.css'
import { AUTH } from '../src/app/auth.js'
import OrderSummaryPreview from './order-summary.vue'

const previews = { 'order-summary': OrderSummaryPreview }
const requested = new URLSearchParams(location.search).get('p')

if (import.meta.env.DEV && previews[requested]) {
  const app = createApp(previews[requested])

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

## Keep fixtures and stubs out of module scope

Put the fixture and the stubs **inside** the component body or `<script setup>`, and
leave module scope to imports. A side effect at module scope keeps the whole harness file
in the production bundle: the bundler cannot drop a module that does something on import,
even when every export is tree-shaken away and the guard means nothing ever calls it.
Measured on Vite 8 — `globalThis.fetch = …` at module scope kept the module and its
fixture strings in `dist/`; the same assignment inside the component body kept nothing.

On Vite the trap no longer applies, because `preview__/` is not a build input at all. It
still bites wherever a loader pulls the folder into the production graph, which is most
of the routed frameworks — the table in `preview-routes.md` says which.

The cleanup's third check is where you find out either way; it is in `preview-routes.md`
under "Removal".

## Faking what the component reaches for

| It uses | Give it |
|---|---|
| `useContext(X)` / a `useX` wrapper | `<X.Provider value={…}>` around the component |
| `inject(KEY)` / `useX` on top of it | `app.provide(KEY, …)` in the preview entry |
| `useRouter` / `useRoute` / `useParams` | a memory router carrying the component's **real path pattern** — see below |
| a data hook (`useQuery`, `useOrder`) | stub the transport under it, not the hook: the component keeps its real loading and error paths |
| a store (Redux, Pinia, Zustand) | the store's own test helper if it has one, otherwise a provider around a hand-built initial state |
| `useTranslation` / `useI18n` | the real i18n instance with the real messages — a fake returns the key, and raw keys on screen read as a broken component |

### A memory router needs the real route pattern

**Params are named by the route pattern, not by the URL you push.** A catch-all route is
the tempting shortcut and it silently hands the component nothing: measured on
vue-router 5, pushing `/orders/ord_1042` at `routes: [{ path: '/:rest(.*)' }]` gives
`params: { rest: 'orders/ord_1042' }`, so `route.params.orderId` is `undefined` and the
component throws on the next line — which the capture then shows you as an exit-4 blank
page you will waste twenty minutes blaming on a provider. With `{ path: '/orders/:orderId' }`
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

Three holes, and each one ends in a real authenticated request when the dev server
proxies `/api` to staging with the developer's cookies:

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

## Next.js and the other routed frameworks

The loader in the routes directory stays thin; the harness file beside it in `preview__/`
carries the fixture, the fakes and the component. In Next's app router that harness file
needs `'use client'` at the top, because providers and hooks are client-side, while the
loader stays a server component.

A route group with its own layout is not inherited from the root: if the component's real
home is inside `app/(dashboard)/`, put the loader in that group or the picture loses the
sidebar, the container width and whatever else that layout supplies.

That layout is real code against a real session, so it draws real data around your fake
fixture — the signed-in name, the org, whatever a sidebar lists. Read the whole frame
before the screenshot goes anywhere.
