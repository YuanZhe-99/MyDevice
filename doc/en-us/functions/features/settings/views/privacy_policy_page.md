# lib/features/settings/views/privacy_policy_page.dart

`PrivacyPolicyPage` is a static settings sub-page that displays the app's privacy policy in the
active locale's language (English, Simplified Chinese, Traditional Chinese, or Japanese), each
variant embedded as a literal Dart string. It has no network or storage access; the only logic is
picking which embedded string to show. Pushed from [`settings_page.dart`](settings_page.md) via
the "Privacy Policy" list tile. See [Platform Notes](../../../../platform-notes.md) and
[Data Formats](../../../../data-formats.md) for the underlying facts this policy text describes
(local-only storage, WebDAV sync, third-party network access for chip search/map tiles/exchange
rates).

**Row-count note:** `grep -c 'Purpose:' privacy_policy_page.dart` returns **3**, matching this
file's 3 real declarations exactly (all three sit directly above the declaration they document).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `PrivacyPolicyPage` (constructor) | constructor | B | Create the page widget (no parameters). |
| `build` | method (widget) | B | Resolve the active locale's policy text and render it in a scrollable, selectable view. |
| `_getText` | method (`PrivacyPolicyPage`) | B | Select which locale-specific policy string to display. |

## Documentation

All three declarations are Tier B. `build` is pure widget composition. `_getText` is a locale
switch that selects between four embedded string constants (`_en`, `_zh`, `_zhTW`, `_ja`) — it has
no side effects and no I/O, so despite the branching it is treated the same as the label/text
lookup helpers classified Tier B elsewhere in this doc set (e.g. `_categoryLabel`/`_sortModeLabel`
in `device_list_page.dart`): a fixed switch over an enum-like input that returns static content,
not business logic. Its only notable behavior (source line 41-53) is checking `languageCode ==
'zh' && countryCode == 'TW'` *before* falling into the plain `switch (locale.languageCode)`, so
Traditional Chinese must be matched by both fields together — a bare `'zh'` match alone would
otherwise select the Simplified Chinese text for Taiwan locales too.
