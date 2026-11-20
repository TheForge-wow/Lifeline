# Lifeline

Clean, lightweight party & raid frames built for WoW Forever, with click-casting, buff reminders and profiles.

- **Download:** [CurseForge](https://www.curseforge.com/wow/addons/lifeline-cell-2)
- **Website & live demo:** https://scryptik-nunya.github.io/lifeline/
- **Bugs, feedback & test builds:** [The Forge Discord](https://discord.gg/yskDeZjQj7) (run `/ll debug` in game and paste the report)

## Releasing

Releases are built and uploaded automatically by the [BigWigs packager](https://github.com/BigWigsMods/packager):

1. Update `## Version:` in `Lifeline.toc`, the fallback version in `Core.lua`, and add the new entry at the top of `CHANGELOG.md`.
2. Commit, then push a tag with the version number (e.g. `1.2.5`).
3. GitHub Actions packages the addon and uploads it to CurseForge (and Wago, if `WAGO_API_TOKEN` is set), plus a GitHub release.

Repository secrets used: `CF_API_KEY` (required for CurseForge), `WAGO_API_TOKEN` (optional).

## License

GPLv3
