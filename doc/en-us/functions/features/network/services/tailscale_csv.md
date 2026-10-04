# lib/features/network/services/tailscale_csv.dart

## Declarations

| Declaration | Kind | Purpose |
|---|---|---|
| `match` | static method | Suggest node-ID, exact-name, then normalized-name matches; expose ambiguity. |
| `TailscaleCsv.parse` | static method | Parse quoted UTF-8 CSV, BOM, multiline cells and trailing blanks. |
| `addresses` | static method | Split and deduplicate the parsed IP cell. |
| `assignment` | static method | Map raw columns and addresses to a membership, preserving manual fields. |

Parsing rejects missing required headers, duplicate headers/node IDs, malformed
quotes, wrong row widths, invalid addresses, dates without timezone and malformed
nonblank booleans. Errors carry row/column or character context. Blank exit status
preserves an existing exit flag; the raw blank remains in `tailscale`. It performs no I/O.
