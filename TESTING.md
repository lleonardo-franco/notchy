# Test plan

A full pass before each release, and the relevant sections for every pull request. Tick each item; if something fails, run `notchy doctor` and include its output in the issue or pull request.

## Install

- [ ] `./install.sh --force` finishes without errors or warnings in the log (`grep -i warning` on the log path it prints)
- [ ] The summary shows **Assinatura: Notchy Local Signing ✓ estável** (stable signature)
- [ ] Running `./install.sh` again skips everything and says it is already up to date
- [ ] Changing a Swift file and running it again rebuilds and reinstalls without asking for permissions
- [ ] `notchy doctor` shows a stable signature, a valid certificate and the granted permissions

## Welcome and settings

- [ ] The welcome window opens on first launch and each **Permitir** button triggers the right request
- [ ] Each row turns into **Pronto** once granted
- [ ] `notchy settings`, the gear in the notch and opening the app from Spotlight all open settings
- [ ] Turning a tab off in settings removes it from the notch

## Notch

- [ ] Hovering opens it; moving the mouse away closes it
- [ ] With "Ao clicar" (on click), it only opens on click
- [ ] With an app in full screen, the notch hides and comes back when leaving
- [ ] Connecting an external display and changing "Onde mostrar" (where to show) moves the notch
- [ ] Locking and unlocking the screen: everything resumes updating

## Music and gestures

- [ ] Spotify and Music show artwork, title and controls
- [ ] Dragging the progress bar seeks
- [ ] Two fingers right: next track; left: previous (and the opposite with the inverted option)
- [ ] Two fingers up and down change the volume, with the level bar showing
- [ ] Haptics follow the chosen strength; the test area responds to clicks and gestures

## Claude Code

- [ ] A new session shows up in the Claude tab with what it is doing
- [ ] A permission request shows up in the notch; Allow, Deny and Answer in terminal all work
- [ ] Clicking a session jumps to the right Terminal or iTerm tab
- [ ] The quota gauges appear after the first response

## Calendar, weather, clipboard

- [ ] Events today, tomorrow and on other days have the right label
- [ ] The Join button opens the meeting; the collapsed notch counts down before it
- [ ] Weather shows the right city (or the one set with `notchy city`)
- [ ] Copying text, an image and a file shows them in Copiados; clicking copies again

## Notifications and Bluetooth

- [ ] A new WhatsApp message and a ClickUp notification animate the counter and show the alert
- [ ] Connecting headphones shows the alert with the battery; the Bluetooth tab lists the devices

## Video

- [ ] With a video in Safari: "Assistir no notch" pauses the tab and resumes at the same second
- [ ] Returning to the tab resumes in the browser at the right spot
- [ ] The same in Chrome
- [ ] Two fingers sideways on the video skip forward and back 10 s
- [ ] Closing the video goes back to the normal notch

## Quit and uninstall

- [ ] The power button and `notchy stop` play the power‑off animation
- [ ] `notchy uninstall` removes the app, hooks and command and restores the previous Claude Code status line
