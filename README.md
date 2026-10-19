# QuitAll

**Quit every open app in one click — except the ones you pick, which get hidden or left as they are.**

[Español](README.es.md) · macOS 13+ · Apple Silicon & Intel · MIT licence · no network, no accounts

End of the day, switching to study mode, about to share your screen: you want a clean Mac without hunting through the Dock. QuitAll lives in the menu bar (no Dock icon). Click its ⏻ icon, press **Quit all**, done.

- **Pick what stays**, in drop-downs by category (Browsers, Communication, Productivity, Music & Audio, Developer Tools, System…), with each app's icon and name. The category comes from the app's own `LSApplicationCategoryType` and you can change it by hand.
- For each app you pick: **Hide** it or **Leave it as is**. Everything else: **Quit**.
- **Polite quitting**: QuitAll asks each app to quit exactly like ⌘Q does, so every app shows its own *save changes?* dialog. After a few seconds (configurable) it tells you which apps are still open — usually because they're waiting for you to save — with **Show**, **Force quit** and **Leave open** for each.
- **Undo**: reopens the apps the last action quit and shows the ones it hid.
- **Safe defaults**: Finder and QuitAll never quit, nor do system components (Dock, Control Center, login window…). Music apps start as *Leave as is* so your music keeps playing.
- **Global shortcut** (default ⌃⌥⌘Q, configurable), optional **open at login**, optional **profiles** (e.g. *Study*, *Focus*) with different lists, Spanish/English.

## Install

**Homebrew** (builds locally with the Xcode Command Line Tools — no Gatekeeper warning):

```bash
brew install jdevesablanco/tap/quitall
quitall install        # copies QuitAll.app to ~/Applications and opens the first-run setup
```

Or the prebuilt app: `brew install --cask jdevesablanco/tap/quitall`.

**Installer (.pkg)** — no Terminal needed: download `QuitAll-x.y.z.pkg` from [Releases](https://github.com/jdevesablanco/QuitAll/releases), then **right-click it → Open** (the first time only) and follow the steps. It installs into *Applications* and opens the first-run setup.

**DMG**: download `QuitAll-x.y.z.dmg` from [Releases](https://github.com/jdevesablanco/QuitAll/releases) and drag the app to *Applications*. The first time, **right-click QuitAll → Open**.

QuitAll is ad-hoc signed, **not notarized** by Apple (that needs a paid Apple Developer account; see [docs/NOTARIZATION.md](docs/NOTARIZATION.md)). That's why macOS asks for confirmation the first time: right-click → *Open*, or *System Settings → Privacy & Security → Open Anyway*. Or skip the dialog: `xattr -dr com.apple.quarantine /Applications/QuitAll.app`.

**From source**: `git clone https://github.com/jdevesablanco/QuitAll && cd QuitAll && Scripts/build-app.sh && open build/QuitAll.app`

## First run

Three short steps (ES/EN switch at the top right): what QuitAll does → which apps shouldn't quit (by category) → how you want to launch it (shortcut, Services menu, open at login). The last screen shows the other apps of the pack.

## Ways to run “Quit all”

| Where | How |
|---|---|
| Menu bar | Click ⏻ → **Quit all**. Tap an app's icon there to cycle quit → hide → keep. Right-click ⏻ for a quick menu. |
| Keyboard | Global shortcut, ⌃⌥⌘Q by default (*Settings → Launch*). No Accessibility permission needed. |
| Services menu | Any app's menu → *Services* → **QuitAll: Quit all** (installed from the app). You can give it its own shortcut in *System Settings → Keyboard → Keyboard Shortcuts → Services*. |
| Dock | Drag QuitAll.app to the Dock and set *Settings → Launch → When QuitAll is opened again → Quit all*: one click on the Dock icon quits everything. |
| URL | `open quitall://quit`, `open "quitall://quit?profile=Study"`, `open quitall://undo` |
| Shortcuts app | *Open URLs* with `quitall://quit`, or *Run Shell Script* with `quitall quit` |
| Terminal | `quitall quit` (see below) |

### What about right-clicking the desktop?

Not possible, honestly. The menu you get by right-clicking the empty desktop belongs to Finder and macOS doesn't let other apps add items to it:

- **Quick Actions / Services** only show up in Finder's context menu when *files are selected*; with nothing selected they're not offered there.
- **Finder Sync extensions** can add items to a folder's background menu, but only for local folders they monitor, they need a sandboxed app extension built with Xcode, and they don't work at all in iCloud Drive / File Provider folders — which includes the Desktop when *Desktop & Documents* sync is on (we tested this with ExSplit).

So QuitAll uses the menu bar, a global shortcut, the Services menu, the Dock, Shortcuts and the `quitall://` URL scheme instead.

## Command line

```bash
quitall plan                       # what would happen to each open app, without touching anything
quitall quit                       # quit politely using the active profile
quitall quit --profile Study --force --timeout 5
quitall undo                       # reopen what the last action quit, show what it hid
quitall rule Spotify keep          # set a rule (quit | hide | keep)
quitall profiles                   # list profiles (* = active)
quitall apps                       # installed apps with category and rule
quitall selftest                   # smoke test, quits nothing
```

The terminal you run `quitall` from is never quit (add `--include-terminal` if you want it to).

## Limitations

- macOS doesn't tell other apps whether a document has unsaved changes. QuitAll can only see that an app is still open after asking it to quit; if it has a window on screen, it's almost always a *save changes?* dialog, so that's what it says.
- **Undo** reopens the apps; which windows and documents come back is up to each app and to *System Settings → Desktop & Dock → Close windows when quitting an application*.
- Only regular apps (the ones with a Dock icon) are quit. Menu bar utilities and background agents are left alone.
- Profiles are optional: the active one is used by the button, the shortcut and the Service; pick it from the menu bar.

Settings live in `~/Library/Application Support/QuitAll/settings.json`.

## Privacy

Everything runs on your Mac. No telemetry. The only network access is when *you* press **Install** on one of the pack's apps (GitHub's public API / Homebrew).

## Pairs well with

Made by the same author, free and open source:

| App | What it does | Status |
|---|---|---|
| [ExSplit](https://github.com/jdevesablanco/ExSplit) | Splits exercise PDFs into one sheet per exercise, from the right-click menu | Available |
| RightYourClick | A better Finder right-click menu, with everything in one place | Available soon |
| **QuitAll** | Quits every app in one click, except the ones you pick | This app |
| SimpleBar | Tidies the menu bar: visible, hidden and always-hidden icons | Available soon |

The app shows the same cards (in the last setup screen and in *Settings → Pairs well with*), detects which ones you have and installs the rest with Homebrew or the latest `.pkg` from GitHub.

## Development

- `Sources/QuitAllCore`: app catalog and categories, protected apps, polite quit + undo (Apple frameworks only).
- `Sources/QuitAllApp`: SwiftUI/AppKit menu bar app. `PackCatalog.swift` is shared verbatim by every app of the pack.
- `Sources/QuitAllCLI`: the `quitall` command.
- `QUITALL_SNAPSHOT=/dir build/QuitAll.app/Contents/MacOS/QuitAll` renders the setup screens to PNG; `QUITALL_CONFIG_DIR=/dir` isolates settings.

## License

MIT © 2026 Julio Devesa Blanco
