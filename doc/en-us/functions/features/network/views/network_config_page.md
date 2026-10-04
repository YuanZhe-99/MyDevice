# lib/features/network/views/network_config_page.dart

## Declarations

| Declaration | Kind | Purpose |
|---|---|---|
| `NetworkConfigPage` | constructor | Bind one membership to a raw config editor. |
| `createState` | method | Create editor state. |
| `initState` | method | Seed original text and format. |
| `dispose` | method | Release controller. |
| `_file` | method | Read/export a chosen UTF-8 file and report errors. |
| `build` | method | Render TOML/YAML label, copy/file actions and raw editor. |

Save returns a membership draft; the caller persists it. Empty text clears config,
whitespace-only text survives. Format changes never convert content. Desktop export
writes the picked path; mobile supplies bytes to the picker. Cancel writes nothing.
