# Code signing policy

Free code signing for the Windows version is provided by [SignPath.io](https://about.signpath.io), certificate by
[SignPath Foundation](https://signpath.org).

- **What is signed:** only `Coremium.exe` built by GitHub Actions from this public repository
  (`.github/workflows/windows.yml`), from tags named `windows-v*`. Nothing built on a personal machine is signed.
- **Team roles:**
  - Committers and reviewers: [Cubinghackerz](https://github.com/Cubinghackerz)
  - Approvers (approve each signing request): [Cubinghackerz](https://github.com/Cubinghackerz)
- **Privacy:** Coremium collects no data. Its only network request is the macOS version's daily check of GitHub for a newer release (it can be turned off in Settings; the Windows version makes none). Settings, history and its crash-recovery file
  stay on your computer in `%LOCALAPPDATA%\Coremium` (Windows) or `~/Library/Application Support/Coremium` (macOS).
- **Source:** MIT-licensed, at https://github.com/Cubinghackerz/Coremium.
