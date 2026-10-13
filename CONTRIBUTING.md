# Contributing to Notchy

**English** · [Português](CONTRIBUTING.pt-BR.md) · [Español](CONTRIBUTING.es.md)

Thanks for wanting to help! Notchy is a small project and every contribution counts, from a typo fix to a whole new tab. This guide explains how to propose changes through a **fork and a pull request**.

## Contents

- [Ways to contribute](#ways-to-contribute)
- [Before you start](#before-you-start)
- [Fork, branch, pull request](#fork-branch-pull-request)
- [Keeping your fork up to date](#keeping-your-fork-up-to-date)
- [Development setup](#development-setup)
- [Project structure](#project-structure)
- [Code style](#code-style)
- [Commit messages](#commit-messages)
- [Testing](#testing)
- [Docs and translations](#docs-and-translations)
- [Review and merge](#review-and-merge)

## Ways to contribute

| | How |
|---|---|
| 🐞 Report a bug | [Open a bug report](https://github.com/lleonardo-franco/notchy/issues/new?template=bug_report.yml) with the output of `notchy doctor` |
| 💡 Suggest a feature | [Open a feature request](https://github.com/lleonardo-franco/notchy/issues/new?template=feature_request.yml) describing the problem it solves |
| 🌍 Translate | Translate the docs or help bring the interface to more languages |
| 📝 Improve the docs | Fix anything unclear, outdated or missing |
| 🛠️ Write code | Pick an issue, especially the ones labeled [`good first issue`](https://github.com/lleonardo-franco/notchy/labels/good%20first%20issue) or [`help wanted`](https://github.com/lleonardo-franco/notchy/labels/help%20wanted) |

Issues and pull requests in English, Portuguese or Spanish are all welcome.

## Before you start

- **Search first.** Someone may already have reported the bug or proposed the idea.
- **Open an issue before big changes.** For anything beyond a small fix, describe what you want to do and wait for a thumbs up. It saves you from building something that won't be merged.
- **Claim the issue.** Comment on it so others know you are working on it.
- **Security problems** never go in public issues. Follow [SECURITY.md](SECURITY.md).

## Fork, branch, pull request

You don't need write access to the repository. All changes come in through pull requests from your own fork.

**1. Fork** the repository with the **Fork** button at the top of [the repo page](https://github.com/lleonardo-franco/notchy). This creates `github.com/<your-user>/notchy`.

**2. Clone your fork** and add the original repository as `upstream`:

```bash
git clone https://github.com/<your-user>/notchy.git
cd notchy
git remote add upstream https://github.com/lleonardo-franco/notchy.git
```

**3. Create a branch** from the latest `main`. Never work directly on `main`.

```bash
git fetch upstream
git switch -c feat/short-description upstream/main
```

| Prefix | For |
|---|---|
| `feat/` | New features |
| `fix/` | Bug fixes |
| `docs/` | Documentation |
| `i18n/` | Translations |
| `refactor/` | Code changes that don't change behavior |
| `chore/` | Build, CI, tooling |

**4. Make your changes**, then build and test them (see [Development setup](#development-setup) and [Testing](#testing)).

**5. Commit** following [Commit messages](#commit-messages) and **push to your fork**:

```bash
git push -u origin feat/short-description
```

**6. Open the pull request.** GitHub shows a **Compare & pull request** button on your fork. Make sure the base is `lleonardo-franco/notchy` → `main`, fill in the template, and link the issue with `Closes #123`. Leave **Allow edits by maintainers** checked so small fixes can be pushed straight to your branch.

**7. Follow up on the review.** Push new commits to the same branch to address feedback. The pull request updates on its own.

## Keeping your fork up to date

```bash
git fetch upstream
git switch main
git merge --ff-only upstream/main
git push origin main
```

To bring your working branch up to date:

```bash
git switch feat/short-description
git rebase upstream/main
git push --force-with-lease
```

## Development setup

**Requirements:** macOS 14 or later, Xcode Command Line Tools (`xcode-select --install`), Python 3.

```bash
swift build              # quick compile check
./build.sh               # builds build/Notchy.app
./install.sh             # installs to /Applications, only rebuilding what changed
./install.sh --force     # full reinstall
```

Use `./install.sh` to try your changes. It signs the app with your local **Notchy Local Signing** certificate, so macOS keeps the permissions between builds. Running an ad‑hoc signed `build/Notchy.app` works, but macOS will ask for permissions again each time.

Useful while debugging:

| | |
|---|---|
| `notchy doctor` | Signature, certificate, permissions and whether the app is running |
| `notchy restart` | Restart after installing |
| `~/.notchy/sessions/` | One JSON file per Claude Code session, written by the hooks |
| `~/.notchy/approvals/` | Pending permission requests and their answers |
| `~/Library/Application Support/Notchy/status.json` | Permission status written by the app |

## Project structure

| Path | What lives there |
|---|---|
| `Sources/Notchy/AppDelegate.swift` | Panel window, mouse tracking, gestures, screen and full‑screen handling |
| `Sources/Notchy/NotchModel.swift` | App state: modes, tabs, sizes, wiring between services |
| `Sources/Notchy/*Service.swift` | One service per integration: music, Claude, calendar, weather, clipboard, badges, Bluetooth, browser media |
| `Sources/Notchy/*Views.swift`, `NotchView.swift` | SwiftUI views |
| `Sources/Notchy/Preferences.swift`, `SettingsView.swift` | Settings and the settings window |
| `Sources/Notchy/PermissionCenter.swift`, `WelcomeView.swift` | Permission checks and onboarding |
| `hooks/` | Claude Code hooks, status line wrapper and their installer |
| `bin/notchy` | Command line tool |
| `install.sh`, `build.sh` | Installer and build script |
| `Resources/` | `Info.plist` and the app icon |

## Code style

- **Swift and SwiftUI.** Models use `@Observable`; UI code runs on the main actor. Services own side effects; views stay thin.
- **No comments in code.** Prefer clear names and small functions that explain themselves.
- **Follow the patterns around you.** Match the naming, file layout and formatting of the code you are editing.
- **Never block the main thread.** Run AppleScript through `AppleScript.run`, which has a timeout.
- **Respect sleep and lock.** Timers and polling must skip work while `SystemActivity.shared.paused` is true.
- **New permission?** Add it to `PermissionCenter`, the welcome window, the usage string in `Info.plist` and the permissions table in every README.
- **Hooks** use only the Python standard library and must run on the system `/usr/bin/python3`.
- **Shell scripts** must work with the bash 3.2 that ships with macOS.
- **Interface text** is in Brazilian Portuguese for now. Keep new strings consistent with it until the app is localized.

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(video): add playback speed control
fix(calendar): show weekday for events after tomorrow
docs: explain how to enable JavaScript from Apple Events
i18n(es): translate the contributing guide
```

Keep each commit focused on one change. A short body explaining *why* is always welcome.

## Testing

There are no automated UI tests yet, so manual testing matters:

1. Run `./install.sh` and try what you changed.
2. Go through the related sections of the [test plan](TESTING.md).
3. Write in the pull request what you tested and on which Mac and macOS version.

Every pull request is built by [GitHub Actions](https://github.com/lleonardo-franco/notchy/actions) on macOS. The build must pass before merging.

## Docs and translations

The README and this guide exist in English, Portuguese and Spanish.

- If you change one of them, update the others too. If you can't, say so in the pull request and someone will help.
- To add a language, create `README.<code>.md` and `CONTRIBUTING.<code>.md` (for example `README.fr.md`) and add it to the language links at the top of every version.
- Localizing the app interface is a bigger change. Open an issue first so we can agree on the approach (String Catalogs).

Add a line describing your change under **Unreleased** in [CHANGELOG.md](CHANGELOG.md).

## Review and merge

- A maintainer reviews pull requests, usually within a few days.
- Changes may be requested; that's a normal part of the process.
- Pull requests are squash‑merged, so the title becomes the commit message. Write it as a Conventional Commit.

By contributing, you agree that your work is licensed under the [MIT License](LICENSE) and that you will follow the [Code of Conduct](CODE_OF_CONDUCT.md).
