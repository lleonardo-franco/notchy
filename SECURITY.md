# Security Policy

## Supported versions

Only the latest release receives security fixes. Update with `notchy update`.

| Version | Supported |
|---|---|
| 1.x (latest) | ✅ |
| < 1.0 | ❌ |

## Reporting a vulnerability

**Please don't open a public issue for security problems.**

Report it privately through [GitHub Security Advisories](https://github.com/lleonardo-franco/notchy/security/advisories/new) (the **Report a vulnerability** button under the **Security** tab). Include:

- what the problem is and what an attacker could do with it;
- steps to reproduce, or a proof of concept;
- the Notchy and macOS versions you tested.

You can expect an answer within a week. Once the issue is confirmed, a fix is prepared and released, and you will be credited in the release notes unless you prefer otherwise.

## Scope

Areas that deserve extra care:

- the Claude Code hooks in `hooks/`, especially the `PermissionRequest` approval flow;
- the files Notchy reads and writes in `~/.notchy` and `~/Library/Application Support/Notchy`;
- the installer and the local code signing certificate it creates;
- AppleScript sent to browsers, terminals and music apps.
