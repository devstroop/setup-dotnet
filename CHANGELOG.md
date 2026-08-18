# Changelog

All notable changes to this project are documented here.

## [Unreleased]

### Added

- **Initial release** — composite action installing a pinned .NET SDK from
  the official dotnetcli release metadata:
  - version semantics: `lts`/`sts`/`latest` channels, channel lines (`9.0`),
    exact SDK versions (`9.0.317`, searched across channels newest-first)
  - SHA-512 verification of every download against the release metadata
  - archive selection filtered to `.tar.gz`/`.zip` (installer formats such
    as `.pkg`/`.msi` are excluded)
  - toolchain caching keyed by exact resolved SDK version (no `restore-keys`
    fallback — a stale-restore hit would fail the version assertion)
  - `DOTNET_ROOT` env export and `PATH` setup for later steps
  - version assertion runs from the install root so a repo `global.json`
    cannot skew it
  - outputs: `dotnet-version`, `dotnet-root`, `cache-hit`
  - Windows install via PowerShell; resolution + assertion in shared bash
  - self-test workflow: channel/line/exact resolution, SHA-512 verification,
    version assertion, smoke app across Linux/macOS/Windows