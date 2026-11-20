# Releasing Lifeline

Releases are built and uploaded automatically by the [BigWigs packager](https://github.com/BigWigsMods/packager):

1. Update `## Version:` in `Lifeline.toc`, the fallback version in `Core.lua`, and add the new entry at the top of `CHANGELOG.md`.
2. Commit, then push a tag with the version number (e.g. `1.2.5`). The `## v1.2.5` section of `CHANGELOG.md` becomes the CurseForge changelog for that upload.
3. GitHub Actions packages the addon and uploads it to CurseForge (and Wago, if `WAGO_API_TOKEN` is set), plus a GitHub release.

Repository secrets used: `CF_API_KEY` (required for CurseForge), `WAGO_API_TOKEN` (optional).
