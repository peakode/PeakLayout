# PeakLayout

**English** · [Türkçe](README.tr.md)

A macOS menu bar app that keeps your desktop icons in a fixed layout — even when you switch between
external monitors.

```
… [D5] [D1]  │  Folder 1
  [D6] [D2]  │  Folder 2
  [D7] [D3]  │  Folder 3
  [D8] [D4]  │  …
```

## Why?

macOS rearranges desktop icons whenever the main display changes. Plug a MacBook into a 49" ultrawide,
close the lid, and your carefully placed folders end up scattered; unplug and it happens again. New
downloads land wherever Finder finds space. PeakLayout puts everything back where it belongs,
automatically.

## Use cases

**1. Laptop at the desk, lid closed.**
You work on a MacBook during the day and connect it to a Samsung 49" monitor at your desk with the lid
closed. The moment the monitor is detected, PeakLayout waits for Finder to finish its own shuffle, then
restores your layout: your main folders in the right-hand column, in the same order as always.

**2. Two desks, two monitors.**
A 27" at home, a 49" at the office. Positions are anchored to the right edge of the screen, so your
pinned column looks identical on both. The wider screen simply has more room for files.

**3. Downloads that don't get lost.**
Every finished download is moved from `~/Downloads` to the desktop and placed in the next free slot.
Files you already have don't move, so you always know where the newest one is: at the end.

**4. Accidental drags and "Clean Up".**
You nudge a folder or Finder re-sorts the desktop. Pinned folders snap back within 20 seconds. Every
layout pass saves a backup of the previous positions, so you can undo with one click.

## How the layout works

- **Right column:** the items you pin (folders, disks…), in the order you choose in Settings.
- **One empty column** as a visual separator.
- **Everything else** fills top to bottom, then moves one column to the left.
- **Append only:** a new file takes the next slot; existing files stay put. Gaps from deleted files
  remain until you choose *Close gaps*. Files are tracked by inode, so renaming keeps their spot.
- **Downloads** are moved only after they finish (size stable for 2 s, not `.crdownload` etc.) and only
  for files that arrive after the app was first launched. Can be turned off.
- **Display changes** (and waking from sleep) re-apply the layout after 3 and 8 seconds.

## Language

The app is available in **English** and **Turkish** and follows your macOS language. To pick a
language just for PeakLayout: *System Settings › General › Language & Region › Applications › +*.

## Installation

Requirements: macOS 14+, Xcode. Replace `DEVELOPMENT_TEAM` in `PeakLayout.xcodeproj` with your own
Apple developer team (Xcode › Signing & Capabilities).

```bash
xcodebuild -project PeakLayout.xcodeproj -scheme PeakLayout -configuration Release -derivedDataPath build
cp -R build/Build/Products/Release/PeakLayout.app /Applications/
open /Applications/PeakLayout.app
```

On first launch macOS asks for permission to control Finder and to access Desktop and Downloads.
*Launch at login* is turned on automatically. Then open the menu bar icon › **Settings…** and add your
pinned items from the desktop. If your Finder icon size differs from the defaults, place the pinned
items where you want them and press **Measure from current positions**.

## Architecture

| File | Responsibility |
|---|---|
| `LayoutEngine.swift` | Cell coordinates from screen size and metrics, slot assignment |
| `FinderBridge.swift` | Reads/writes `desktop position` via AppleScript (batched in one script) |
| `DesktopScanner.swift` | Maps Finder names to the file system, skips hidden/Office leftovers |
| `DirectoryWatcher.swift` | Watches `~/Desktop` and `~/Downloads` |
| `DownloadsMover.swift` | Moves finished downloads to the desktop |
| `DisplayMonitor.swift` | Display changes and wake from sleep |
| `AppModel.swift` | Ties it all together; backs up positions before every pass |

Finder coordinates are in points from the top-left of the main display. Default metrics match an
88 pt icon size with 14 pt text (right inset 160, first row 83, column step 108, row step 126).
UI strings live in `Localizable.xcstrings`; permission prompts in `InfoPlist.xcstrings`.

## Backups

`~/Library/Application Support/PeakLayout/Backups/` holds the positions before each layout pass (last 20).
*Restore last backup* in Settings pauses the automatic layout and restores them.

## Icons

Both icons are drawn in code with CoreGraphics: a snowy peak made of grid tiles, an empty column and
the pinned column.

```bash
# App icon
A=PeakLayout/Assets.xcassets/AppIcon.appiconset
swift scripts/render-icon.swift $A/icon_1024.png
for s in 16 32 64 128 256 512; do sips -z $s $s $A/icon_1024.png --out $A/icon_$s.png; done

# Menu bar template icon (18 pt, 1x/2x/3x)
swift scripts/render-menubar-icon.swift PeakLayout/Assets.xcassets/MenuBarIcon.imageset
```

## License

[MIT](LICENSE) © 2026 Peakode
