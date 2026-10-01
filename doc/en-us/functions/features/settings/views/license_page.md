# lib/features/settings/views/license_page.dart

`LicensePage` is a static settings sub-page that displays the app's GNU GPLv3 license text
(embedded as a literal Dart string) in a scrollable, selectable text view. Since 1.6.0 the same
string ends with a notice that the Simplified/Traditional Chinese conversion tables used by the
optional on-device AI insight cards
([`chinese_convert_data.md`](../../../shared/utils/chinese_convert_data.md)) are derived from
OpenCC, Copyright (c) Carbo Kuo and contributors, under the Apache License 2.0. Since 1.6.1 it
also ends with a notice that bundled images are not part of the GPL-3.0 source (pointing to the
three `SOURCES.md` files), that some device thumbnails are manufacturers' product images, and
that all product names, logos and brands are trademarks of their owners. It has no state, no
network or storage access, and no branching logic — it is pushed from
[`settings_page.dart`](settings_page.md) via the "License" list tile.

**Row-count note:** `grep -c 'Purpose:' license_page.dart` returns **2**, matching this file's
2 real declarations exactly (both directly above the declaration they document).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `LicensePage` (constructor) | constructor | B | Create the page widget (no parameters). |
| `build` | method (widget) | B | Render an app bar and the scrollable, selectable GPLv3 license text (plus the OpenCC notice), capped at `readingMaxWidth` and centred. |

## Documentation

Both declarations are Tier B: the constructor is a trivial `const` forwarding constructor, and
`build` only composes a `Scaffold`/`SingleChildScrollView`/`SelectableText` around the file's
embedded `_licenseText` constant, with no conditional logic, loops, or I/O.

## Bottom padding behind the floating bar (since 1.7.1)

The Expressive bottom bar floats over the page (`ShellScaffold` uses `extendBody`), so a scroll view with an explicit `padding` passes it through `navBarAwarePadding(context, ...)` (see [`adaptive_layout.md`](../../../shared/utils/adaptive_layout.md)) to scroll its last content above the bar. Covered here: the `SingleChildScrollView` (padding 16), which is also a settings detail pane page. On a pushed route the extra inset is just the system's, so nothing changes there.
