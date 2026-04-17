# actual-server-patched

A minimal overlay Docker image for [Actual Budget](https://github.com/actualbudget/actual) that excludes future-dated transactions from the displayed account balances.

## The problem

Actual's sidebar account balance sums every transaction in the account regardless of date. If you pre-enter projected income (e.g. future paychecks) so that envelope budgeting can forecast the coming months, those projected amounts inflate the "current" balance shown in the sidebar and in the on-budget / off-budget / all-accounts aggregates.

There's no setting to change this — the query in `packages/desktop-client/src/spreadsheet/bindings.ts` has no date filter.

## The fix

A ~10-line patch to `bindings.ts` adds `date: { $lte: currentDay() }` to four balance queries:

- per-account `balance`
- all-accounts aggregate
- on-budget accounts aggregate
- off-budget accounts aggregate

The cleared / uncleared balances, the register running-balance column, and all reports (net worth, cash flow, etc.) are unchanged.

## What it does NOT change

- **Budget forecasting still works.** The envelope budget's `total-income` / `available-funds` / `to-budget` for future months read from the real `transactions` table with their own date ranges. Projected paychecks still feed the future-month budget correctly — they just no longer inflate today's balance.
- **Reports are untouched.** Net worth over time, spending by category, etc. use their own queries.
- **Day rollover.** `currentDay()` is evaluated when a spreadsheet cell is registered. If the app stays open across midnight, balances won't refresh until a transaction change or a reload. Acceptable for most users.

## How it's built

The `Dockerfile` is a two-stage build:

1. `builder` stage: clone upstream `actualbudget/actual` at a pinned tag, apply every patch in `patches/`, run `yarn workspace @actual-app/web build` to produce the static SPA.
2. `prod` stage: start from `actualbudget/actual-server:<same-tag>` and overlay the patched `build/` into `/app/node_modules/@actual-app/web/build`.

No server code is modified. The balance calculation runs client-side against a CRDT-backed WASM SQLite in the browser, so only the web bundle needs patching.

## Usage

Replace `actualbudget/actual-server:latest` with `ghcr.io/danielhopkins/actual-server-patched:latest` in your compose file:

```yaml
services:
  actual-budget:
    image: ghcr.io/danielhopkins/actual-server-patched:latest
    # ...everything else stays the same
```

Image tags:
- `latest` — tracks upstream latest
- `vX.Y.Z` — pinned to a specific upstream release (e.g. `v26.4.0`)

Images are multi-arch (`linux/amd64`, `linux/arm64`).

## Keeping up with upstream

A daily GitHub Actions workflow (`.github/workflows/build.yml`) polls `actualbudget/actual` for its latest release, and if the corresponding tag isn't already published to GHCR, builds and pushes it.

If upstream refactors `bindings.ts` in a way that breaks the patch, the build will fail loudly and I'll need to regenerate the patch against the new source.

## Manual build

```
docker build --build-arg UPSTREAM_TAG=v26.4.0 -t actual-server-patched:local .
```

## License

The patch and build configuration are MIT. Actual itself is MIT-licensed upstream.
