<div align="center">

<img src="docs/icon.png" width="112" alt="Notchy icon">

# Notchy

**Your MacBook notch, finally useful.**<br>
Music, Claude Code, calendar, YouTube and notifications, right where the camera lives.

[![Release](https://img.shields.io/github/v/release/lleonardo-franco/notchy?color=d97757&label=release)](https://github.com/lleonardo-franco/notchy/releases)
[![Build](https://github.com/lleonardo-franco/notchy/actions/workflows/build.yml/badge.svg)](https://github.com/lleonardo-franco/notchy/actions/workflows/build.yml)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-111?logo=apple)](#requirements)
[![Swift](https://img.shields.io/badge/Swift-SwiftUI-F05138?logo=swift&logoColor=white)](Package.swift)
[![License: MIT](https://img.shields.io/badge/license-MIT-3b82f6)](LICENSE)
[![PRs welcome](https://img.shields.io/badge/PRs-welcome-22c55e)](CONTRIBUTING.md)

**English** · [Português](README.pt-BR.md) · [Español](README.es.md)

<br>

<img src="docs/hero.svg" width="100%" alt="Notchy expanded under the MacBook notch, showing the current song, Claude Code sessions and tabs">

</div>

---

Notchy turns the notch into a tiny control center. Collapsed, it shows only what matters on each side of the camera: album art, your Claude Code status, a countdown to the next meeting, unread badges. Hover it and it opens into a player with tabs and controls. Close it and it powers off like an old CRT.

> [!NOTE]
> The app interface is currently in Brazilian Portuguese. Translating it is one of the best first contributions you can make, see [Contributing](#contributing).

## Contents

- [Features](#features)
- [Requirements](#requirements)
- [Install](#install)
- [Usage](#usage)
- [Permissions](#permissions)
- [How it works](#how-it-works)
- [FAQ](#faq)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

## Features

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>🎵 Music</h3>
      Spotify and Apple Music with artwork, title and controls. Drag the progress bar to seek. The notch picks up a tint from the album cover.
    </td>
    <td width="50%" valign="top">
      <h3>🤖 Claude Code</h3>
      Live status of every session. <b>Approve or deny permission requests from the notch</b>, jump to the right Terminal or iTerm tab, and keep an eye on your 5‑hour and 7‑day quota.
    </td>
  </tr>
  <tr>
    <td valign="top">
      <h3>▶️ YouTube in the notch</h3>
      Playing a video in Safari, Chrome, Brave, Edge or Chromium? Send it to a mini player under the notch. It resumes at the same second and hands back to the tab when you are done.
    </td>
    <td valign="top">
      <h3>📅 Calendar</h3>
      Upcoming events with a <b>Join</b> button for Zoom, Meet, Teams and Webex, plus a countdown in the collapsed notch before each meeting.
    </td>
  </tr>
  <tr>
    <td valign="top">
      <h3>🔔 Notifications</h3>
      Animated unread counters for WhatsApp and ClickUp, read from their Dock badges.
    </td>
    <td valign="top">
      <h3>🎧 Bluetooth</h3>
      Battery for headphones and other devices, AirPods left, right and case included, with low‑battery alerts.
    </td>
  </tr>
  <tr>
    <td valign="top">
      <h3>🌤️ Weather and clipboard</h3>
      Temperature next to the clock with an hourly forecast (Open‑Meteo), and the last 30 things you copied, kept in memory only.
    </td>
    <td valign="top">
      <h3>✋ Gestures and haptics</h3>
      Two‑finger swipes change tracks and volume. Trackpad haptics with adjustable strength, and a touchpad‑shaped area to try them out.
    </td>
  </tr>
</table>

## Requirements

- A Mac with macOS 14 Sonoma or later. Macs without a notch work too, using a virtual notch on the main screen.
- Xcode 16 or later, or its Command Line Tools: `xcode-select --install`
- Python 3, which ships with the Command Line Tools
- [Claude Code](https://docs.claude.com/en/docs/claude-code) is optional and only needed for the Claude tab

## Install

```bash
git clone https://github.com/lleonardo-franco/notchy.git ~/Projects/notchy
cd ~/Projects/notchy
./install.sh
```

The installer builds the app, copies it to `/Applications`, wires up the Claude Code hooks and installs the `notchy` command. The first run also:

1. creates a local code signing certificate, **Notchy Local Signing**, and asks for your Mac password once to trust it;
2. opens a welcome window where you grant only the permissions you want.

Because every build is signed with the same certificate, macOS keeps your permissions across updates, and later runs only rebuild what changed.

**Update** with `notchy update`. **Remove everything** with `notchy uninstall`.

## Usage

| Command | What it does |
|---|---|
| `notchy` | Start |
| `notchy stop` / `restart` | Quit with the power‑off animation / restart |
| `notchy settings` | Open settings |
| `notchy welcome` | Show the welcome and permissions window |
| `notchy city "Lisbon"` | Set the weather city (`notchy city auto` to go back to automatic) |
| `notchy doctor` | Check signature, certificate and permissions |
| `notchy update` | Pull the latest version and reinstall |
| `notchy uninstall` | Remove the app, hooks, settings and command |

| Gesture on the open notch | Action |
|---|---|
| Two fingers right / left | Next / previous track (configurable) |
| Two fingers up / down | Volume |
| Two fingers sideways on a video | Skip ±10 s |

## Permissions

Everything is opt‑in. Notchy works with any subset of these.

| Permission | Used for |
|---|---|
| Accessibility | Reading WhatsApp and ClickUp badge counts from the Dock |
| Automation: Safari, Chrome | Finding YouTube videos, pausing the tab and resuming at the same spot |
| Automation: Spotify, Music | Showing and controlling playback |
| Automation: Terminal, iTerm | Jumping to the right Claude Code session |
| Calendars | Upcoming meetings |
| Bluetooth | Device battery levels |

> [!TIP]
> To resume videos at the exact second, enable **Allow JavaScript from Apple Events** in the browser's Develop menu. In Safari, turn on the Develop menu in Settings → Advanced → Show features for web developers.

## How it works

<details>
<summary>Architecture overview</summary>

<br>

| Piece | How |
|---|---|
| Window | An `NSPanel` above the menu bar, positioned from the notched screen's `safeAreaInsets` |
| Music | Distributed notifications from Spotify and Music, plus AppleScript |
| Claude Code | Hooks write each session's state to `~/.notchy/sessions`; the `PermissionRequest` hook waits for the notch's answer; a status line wrapper provides the quota |
| Video | AppleScript reads browser tabs; the player is the YouTube IFrame API in a `WKWebView` |
| Notifications | Dock badge labels via the Accessibility API |
| Bluetooth | `system_profiler SPBluetoothDataType` |
| Haptics | The trackpad actuator directly, so it works while the app is in the background |
| Full screen | Detects full‑screen Spaces to hide the notch |

Periodic checks pause while the screen is locked or the Mac is asleep, and slow down while the notch is closed.

```
Sources/Notchy/   SwiftUI app, services and views
hooks/            Claude Code hooks and status line (Python, stdlib only)
bin/notchy        Command line tool
install.sh        Installer, signing and incremental updates
build.sh          Builds build/Notchy.app
```

</details>

## FAQ

<details>
<summary><b>Why does it ask for my password during the first install?</b></summary>
<br>
To trust the local signing certificate and let <code>codesign</code> use it without prompting again. It happens once. Without a stable signature, macOS would ask for every permission again after each update.
</details>

<details>
<summary><b>Does it send my data anywhere?</b></summary>
<br>
No. The only network calls are to Open‑Meteo and an IP geolocation service for the weather, and to YouTube when you play a video in the notch. The clipboard history lives in memory and disappears when the app quits.
</details>

<details>
<summary><b>Will it mess with my Claude Code status line?</b></summary>
<br>
No. The installer wraps your existing status line and keeps it. <code>notchy uninstall</code> restores the original.
</details>

<details>
<summary><b>Is there a prebuilt download?</b></summary>
<br>
Not yet. Notchy is built from source on your Mac. A signed and notarized build is on the roadmap.
</details>

## Roadmap

- [ ] Interface in English and Spanish ([#1](https://github.com/lleonardo-franco/notchy/issues/1), [#2](https://github.com/lleonardo-franco/notchy/issues/2))
- [ ] Signed and notarized releases ([#9](https://github.com/lleonardo-franco/notchy/issues/9))
- [ ] Homebrew ([#8](https://github.com/lleonardo-franco/notchy/issues/8))
- [ ] More badge sources: Slack, Telegram, Discord ([#4](https://github.com/lleonardo-franco/notchy/issues/4), [#5](https://github.com/lleonardo-franco/notchy/issues/5))
- [ ] Screenshots and a demo video in this README ([#3](https://github.com/lleonardo-franco/notchy/issues/3))

Have an idea? [Open a feature request](https://github.com/lleonardo-franco/notchy/issues/new/choose).

## Contributing

Contributions of every size are welcome: bug reports, ideas, translations, docs and code. Read the [contributing guide](CONTRIBUTING.md) to learn how to fork the repo, set up the project and open a pull request. Look for issues labeled [`good first issue`](https://github.com/lleonardo-franco/notchy/labels/good%20first%20issue) to get started.

Everyone taking part is expected to follow the [Code of Conduct](CODE_OF_CONDUCT.md). Found a security problem? See [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE) © Leonardo Franco Lima

<div align="center">
<sub>If Notchy made your notch a little less useless, consider giving it a ⭐</sub>
</div>
