# lib/app/router.dart

Defines `appRouter`, the app's `GoRouter` configuration: a single `ShellRoute` wrapping
`ShellScaffold` with five top-level routes (`/devices`, `/services`, `/network`, `/datasets`,
`/settings`), matching the five bottom tabs described in
[../../architecture.md](../../architecture.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `appRouter` | top-level `final` variable | B | The app's `GoRouter` instance/route table. |

This file has zero rows from the `/// Purpose:` convention: `appRouter` is a plain top-level
`final` value (a `GoRouter` configuration literal), not a function/method/constructor/getter/
setter, so it falls outside the Function Explanation Layer convention — the same situation as
`app/router.dart` in the sibling MyAnime repo.
