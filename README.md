# Topsoil (personal build)

A native macOS notch dashboard: a borderless panel that hugs the MacBook notch and
expands on hover into a stack of modules — **Now Playing**, **Calendar**,
**Battery / System**, and a **Drop Shelf**.

Built entirely with Swift Package Manager — **no Xcode required**.

## Dashboard and personalization

Click the notch to open your workspace. Named tabs jump directly between pages;
**Find a tool** searches enabled modules by name and description. Use **⌘[** and
**⌘]** to change pages while the panel has keyboard focus, or swipe sideways.

In **Settings → Design**, choose paged tiles, priority (a wider first tile), or
full-page focus. **Settings → Modules** includes search, descriptions, toggles,
and drag-to-reorder; clear the search before reordering. The settings window is
resizable and remembers its position.

## Requirements

- macOS 14+ (developed and run on macOS 26, Apple Silicon)
- Swift 6 toolchain (the Command Line Tools are enough — Xcode is not needed)

## Build & run

```bash
make test     # build and run the unit suite (swift run TopsoilTests)
make run      # build, package Topsoil.app, and launch it
make package  # just build the signed .app into ./build
```

`make run` launches Topsoil as a **menu-bar agent** (no Dock icon). Use the
menu-bar icon for **Open Topsoil**, **Open Settings…**, and **Quit Topsoil**.

## Public identity checks

Before a public build:

```bash
rg -n '"MacNotch"|>MacNotch<|Quit MacNotch|MacNotch Settings|com.macnotch.app' \
  Sources Scripts Makefile README.md website/index.html
```

Expected: no public-facing launch copy remains except legacy migration code (the retained `io.notchapple.NotchApple` bundle id and `NotchApple`/`MacNotch` support directories) and historical documentation that explicitly says it is legacy.

> Tests use a self-contained runner (`Sources/TopsoilTests`) instead of XCTest,
> because XCTest ships only with Xcode. Run them with `swift run TopsoilTests`;
> the process exits non-zero if any check fails.

## Permissions

Granted on first use; nothing is requested up front:

- **Calendar** (EventKit) — prompted the first time the Calendar module refreshes.
- **Automation: Music / Spotify** (AppleScript) — prompted the first time you use the
  media controls. If Music or Spotify is already running, the same Automation prompt
  can also appear on the first media refresh.
- Battery/CPU/RAM and the Drop Shelf need no permissions.

Because the app is **ad-hoc signed** for personal use, macOS may re-prompt for these
after a rebuild (the signature changes). Just re-grant.

## Modules

| Module | What it shows | Data source |
|--------|---------------|-------------|
| Now Playing | Track + transport controls; equalizer glance when collapsed | AppleScript (Music/Spotify) behind a `MediaSource` seam; opportunistic MediaRemote |
| Calendar | Today's date + upcoming events | EventKit |
| Battery / System | Battery %, charge state, CPU, RAM | IOKit + `host_statistics` |
| Drop Shelf | Files dragged onto the notch; drag them back out | Security-scoped bookmarks |

Modules can be enabled/disabled and reordered in **Settings**, which also has a
**Launch at login** toggle. Changes apply to the notch immediately.

## Manual test checklist

These need a real notch and a person at the keyboard (the unit suite covers the
pure logic headlessly):

- [ ] Notch shape sits under the physical notch; expands on hover, collapses on exit.
- [ ] Now Playing shows the current track and play/pause/next control Music or Spotify.
- [ ] Calendar shows today's events after access is granted; "Grant access" opens System Settings when denied.
- [ ] Battery / CPU / RAM update live.
- [ ] Drag a file onto the expanded panel → a chip appears; it survives a relaunch; drag the chip back into Finder.
- [ ] Settings toggles/reorders modules live; "Launch at login" registers Topsoil in System Settings → General → Login Items.

## Architecture

Design spec: [`docs/superpowers/specs/2026-06-22-macnotch-phase1-design.md`](docs/superpowers/specs/2026-06-22-macnotch-phase1-design.md).

All code lives in the `TopsoilKit` library; the internal `Topsoil` executable
target is a thin entry point. Each feature conforms to the `NotchModule` protocol, and the window
renders whatever modules are enabled, in order — adding a module is drop-in.

This is **Phase 1**. Later modules (weather, Pomodoro, GitHub, notifications,
translation, Bluetooth, and the AirDrop/zip/convert *drop actions*) plug into the
same `NotchModule` seam.

Build artifacts land in `./build` (git-ignored).
