# lib/shared/widgets/template_icon.dart

`TemplateIcon` renders a bundled transparent SVG or raster image in a circular avatar. It uses `BoxFit.contain`
inside a square 64% of the circle diameter, keeping even the square's corners within the circle.
A missing asset uses the supplied Material fallback; loading and SVG errors also show that fallback.
An optional foreground colour tints monochrome device-brand assets; multicolour service marks keep their accents while currentColor follows the theme.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `TemplateIcon` | constructor | B | Configure the asset, fallback, diameter and optional tint. |
| `build` | method | B | Render the full mark with circular-safe spacing and a loading/error fallback. |

## Documentation

This widget reads only bundled assets. It does not crop, download, or persist image data.
