# Security

Coremium is a small, local-only utility. What it does and doesn't touch:

- **Only your own user's processes.** It changes scheduling priority (`setpriority`, the same effect as `taskpolicy -b`) and
  nothing else. It never touches other users' or system processes, and has no root helper.
- **One network request, nothing sent about you.** Once a day the macOS app asks GitHub's public releases API whether a newer
  version exists (turn it off in Settings). Updates install only after you click Update and the download's SHA-256 matches
  the published checksum. No telemetry, no account.
- **Reversible.** Quitting, pausing, or running `Coremium.app/Contents/MacOS/Coremium --restore-all` puts every process back.
- **Local data only:** `~/Library/Application Support/Coremium` (settings, usage history, crash-recovery file). Delete it any time.
- It is ad-hoc signed and **not notarized** (no paid Apple developer account). Verify downloads against the published
  `.sha256`, or build from source with `scripts/build.sh`.

## Reporting a vulnerability

Please open a private security advisory on GitHub (Security tab › Report a vulnerability) rather than a public issue.
