# Profile (name and avatar)

P3 delegates model, merge, storage coordination and avatar components to
`myapps_profile`; app providers, picker, module registration and edit dialog retain
the behaviors below. See [../shared-ui.md](../shared-ui.md).

Since 1.7.0 the app has a small user profile: a **display name** and an **avatar**. Both are
optional, and both sync to every device through WebDAV and are included in backups. Per-file detail
is in [`../functions/features/profile/`](../functions/features/profile/services/profile_store.md);
the file format is in [`../data-formats.md`](../data-formats.md#profilejson) and the sync rules in
[`../sync.md`](../sync.md#the-profile-file).

## Where it appears

- **home page app bar.** The avatar, in a small circle, sits at the left of the "MyDevice!!!!!" title.
  Tapping it opens Settings (the app bar button's tooltip is *Profile and settings*). With nothing
  set it shows a person icon; with a name but no avatar it shows the first letter of the name.
- **Settings header.** A *Profile* row is the first item of the Settings list, before *General*, so it
  appears in both the one-pane and the two-pane layout. It shows a larger avatar, the name (or the
  placeholder *Set your name*), the hint *Name and avatar sync across your devices*, and an edit
  icon. Tapping it opens the edit dialog.

## Editing

The edit dialog (*Profile*) holds the large avatar, a *Choose avatar* button, an *Adjust avatar* button
and a *Remove* button that appear only while an avatar is set, and a *Name* field (at most 40
characters). Tapping the large avatar adjusts the current one, or picks one when there is none.

- **Avatar changes save immediately.** *Choose avatar* opens the platform file picker for an image
  and then the avatar editor (below); saving there stores the avatar, and backing out stores nothing.
  *Adjust avatar* (since 1.7.1) opens the editor on the current avatar again; *Remove* clears the
  avatar. If the chosen file cannot be used as an image, a snack bar says *This image could not be
  used* and nothing changes.
- **The name saves on Save.** Cancel discards it. The name is trimmed; an empty name clears it, and
  saving an unchanged name writes nothing.

## Avatar editor (since 1.7.1)

After picking, a full-screen editor frames the avatar: the image sits under a **circular mask**
(the avatar is shown as a circle everywhere) inside an `InteractiveViewer` — drag to move, pinch or
scroll the wheel to zoom 1x to 8x; the image always covers the circle (`boundaryMargin: zero`).
The app bar has **Rotate** (90 degrees clockwise), **Reset** (centred, filling the circle) and
**Save**, with a hint line beneath. Saving maps the visible square back through the zoom and pan to
source pixels and crops exactly that.

## Avatar processing

The picked image is decoded, rotated upright according to its EXIF orientation (and by the editor's
rotation), limited to 2048 pixels on its longest edge for the editor, cropped to the **square** the
user framed (the centred square when no editor is used), scaled to **512 x 512** pixels and stored
as a **JPEG** (quality 88) at `images/avatar_<uuid>.jpg`. The work runs in a separate isolate so the
UI does not stall. The stored avatar is already 512 pixels, so adjusting it again can only zoom
further in, rotate or re-centre A fresh
file name is used for every avatar. Replacing or removing the avatar deletes the previous avatar file
on that device only.

## Sync

The profile is the fifth synced data module (`profile.json`). Each field has its own timestamp and
merges by last writer wins, so changing the name on one device and the avatar on another keeps both;
there is never a conflict dialog. The avatar image travels with the device images through the additive image
phase. Because image sync never overwrites or deletes, old avatar files stay on the WebDAV server and
on other devices — a known limitation. Builds older than 1.7.0 never request the file, and each sync
costs one extra `GET profile.json`. Backups include `profile.json` (restore label *Profile*) and the
avatar file, and ZIP export includes both. See [`../sync.md`](../sync.md#the-profile-file) and
[`../backup-restore.md`](../backup-restore.md).

## Behavior notes

- A profile edited on another device appears without restarting: the profile state reloads whenever
  sync or a restore rewrites local data.
- If the avatar file has not reached this device yet, the placeholder is shown until it does.
