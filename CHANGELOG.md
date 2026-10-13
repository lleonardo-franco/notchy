# Changelog

All notable changes to Notchy are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project follows [Semantic Versioning](https://semver.org/).

## Unreleased

- README and contributing guide in English, Portuguese and Spanish
- Issue templates for bugs, features and translations, and a pull request template
- Code of Conduct and security policy
- Build check on GitHub Actions for every pull request
- Real app icons for notification badges, the music player, the browser of a YouTube video and the permission list
- Unread badges for Slack, Telegram and Discord
- Playback speed in the YouTube mini player (1×, 1.25×, 1.5×, 2×), carried over from and back to the browser tab

## 1.0.0

- Welcome window listing every permission, its status and a button to grant it
- Claude Code hooks bundled with the app, with status and an install or reinstall button in settings
- AppleScript calls with a timeout, so a frozen app can't block music, video or the terminal jump
- Periodic checks pause while the screen is locked or the Mac is asleep, and slow down while the notch is closed
- Choose the screen (notched, main, or notched screens only) and hide the notch in full‑screen apps
- `notchy doctor` with permission status, plus `notchy update`, `notchy uninstall`, `notchy welcome` and `notchy version`
- `./install.sh --uninstall`
- README, test plan, license and changelog

## 0.9.1

- YouTube videos from Safari too

## 0.9.0

- YouTube in the notch: a mini player that resumes at the same second as the tab and hands back to it at the same spot
- Bluetooth tab with device battery, headphone battery at the top of the notch, and connection and low‑battery alerts

## 0.8.2

- Touchpad‑shaped area to test haptics and gestures
- Gesture logic shared between the notch and the test area

## 0.8.1

- Configurable haptic strength, independent from sound

## 0.8.0

- Configurable track‑change direction (right = next by default)
- Two fingers up and down change the volume, with a level bar in the notch

## 0.7.2

- Calendar shows "tomorrow" or the weekday correctly

## 0.7.1

- Haptics through the trackpad actuator, working while the app is in the background

## 0.7.0

- Settings window
- Trackpad gestures
- Calendar with a Join button and a countdown to meetings
- WhatsApp unread counter

## 0.6.0

- Power‑off animation in the style of an old CRT (slower in 0.6.1)

## 0.5.0

- Animated ClickUp notification counter

## 0.4.0

- Weather with an hourly forecast
- Clipboard history

## 0.3.0

- New icon
- Collapsed notch without the session count and with the running task timer
- More reliable jump to the terminal

## 0.2.0

- Approve Claude Code permissions from the notch
- Click a session to jump to the right terminal tab
- 5‑hour and 7‑day usage quota
- Sound and haptics on alerts
- Draggable progress bar and album color background
- App icon and installer

## 0.1.0

- First version: Spotify and Music playback and Claude Code sessions in the notch

## Installer

Over these versions `install.sh` gained a progress bar, incremental updates that rebuild only what changed, signing with a stable local certificate, and a one‑time cleanup of permissions left over from ad‑hoc signing.
