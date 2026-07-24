# lib/features/settings/views/license_page.dart

`LicensePage` is a static settings sub-page that displays the app's GNU GPLv3 license text
(embedded as a literal Dart string) in a scrollable, selectable text view. It has no state, no
network or storage access, and no branching logic — it is pushed from
[`settings_page.dart`](settings_page.md) via the "License" list tile.

**Row-count note:** `grep -c 'Purpose:' license_page.dart` returns **2**, matching this file's
2 real declarations exactly (both directly above the declaration they document).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `LicensePage` (constructor) | constructor | B | Create the page widget (no parameters). |
| `build` | method (widget) | B | Render an app bar and the scrollable, selectable GPLv3 license text. |

## Documentation

Both declarations are Tier B: the constructor is a trivial `const` forwarding constructor, and
`build` only composes a `Scaffold`/`SingleChildScrollView`/`SelectableText` around the file's
embedded `_licenseText` constant, with no conditional logic, loops, or I/O.
