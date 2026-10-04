# Workload Modeling Tools

Use repo-native scenario, browser, API, performance, or property/stateful tooling first. Add a new workload tool only when the existing stack cannot express realistic sessions, variance, replay, or assertions.

## Tool Categories

| Category | Examples | Use |
| --- | --- | --- |
| Browser/E2E | Playwright, Cypress, Selenium/Appium. | User sessions where UI, routing, auth, and backend wiring matter. |
| API/load scenarios | k6, Locust, Gatling, JMeter. | Traffic mixes, authenticated API sessions, thresholds, and dependency behavior. |
| Stateful/property | Hypothesis state machines, fast-check model-based tests, jqwik, proptest. | Generated operation sequences with invariants after each transition. |
| CLI/operator scripts | Existing integration harnesses, shell test frameworks, golden command tests. | Developer or operator sessions with files, config, credentials, and process exits. |
| Synthetic monitors | Playwright/k6 monitors, provider synthetics, smoke jobs. | Critical production-like availability and contract paths. |

## Repo Signals To Inspect

| Signal | Common Patterns | Evidence |
| --- | --- | --- |
| Existing workload tooling | `playwright`, `cypress`, `k6`, `locust`, `gatling`, `jmeter`, `hypothesis`, `fast-check`. | Preferred implementation style and commands. |
| User/session paths | `checkout`, `signup`, `onboarding`, `import`, `export`, `admin`, `recovery`, `settings`, `workflow`. | Candidate tasks users actually perform. |
| Stateful boundaries | `queue`, `job`, `retry`, `idempot`, `cache`, `transaction`, `migration`, `webhook`. | Areas where sequences expose bugs. |
| Variance hooks | `seed`, `random`, `factory`, `fixture`, `faker`, `scenario`, `dataset`. | Existing ways to vary data while keeping replay. |
| Safety controls | `cleanup`, `teardown`, `rateLimit`, `sandbox`, `staging`, `dryRun`. | Whether workload execution has acceptable blast radius. |

## Common Commands And Patterns

| Goal | Starting Commands |
| --- | --- |
| Find workload tools | `rg "playwright|cypress|k6|locust|gatling|jmeter|hypothesis|fast-check|proptest|synthetic" .` |
| Find user workflows | `rg "checkout|signup|onboard|import|export|admin|recovery|settings|workflow|journey|scenario" README* docs src app test tests e2e` |
| Find risky sequences | `rg "queue|job|retry|idempot|cache|transaction|migration|webhook|eventual|backfill" src test tests` |
| Find seeded variance | `rg "seed|random|faker|factory|fixture|scenario|dataset" test tests e2e src` |
| Find safe cleanup | `rg "cleanup|teardown|afterEach|afterAll|sandbox|staging|dryRun|rateLimit" test tests e2e scripts .github` |

## Evidence Rules

- A workload is justified when the bug risk comes from interaction across steps, state, timing, scale, or boundaries.
- Variance must be bounded, recorded, and replayable.
- Correctness assertions must run during the workload; throughput alone is not enough.
- A failing workload should produce a deterministic regression case or a captured replay artifact.
- Do not run workloads against shared or production systems without explicit safety controls.

## Source Anchors

- Playwright, [test isolation](https://playwright.dev/docs/browser-contexts)
- Grafana k6, [options and thresholds](https://grafana.com/docs/k6/latest/using-k6/thresholds/)
- Locust, [tasks and wait time](https://docs.locust.io/en/stable/writing-a-locustfile.html)
- Hypothesis, [stateful testing](https://hypothesis.readthedocs.io/en/latest/stateful.html)
