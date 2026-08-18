# Contributing

## Local testing

The shell scripts can be exercised directly (see `README.md`). Resolution
needs no network beyond the official release metadata; `install` downloads
the SDK archive + SHA-512 digest from builds.dotnet.microsoft.com.

```bash
# Resolve only (no side effects)
INPUT_VERSION=lts bash scripts/setup-posix.sh resolve

# Full install into a scratch tool cache
INPUT_VERSION=9.0.317 RUNNER_TOOL_CACHE=/tmp/dotnet-cache \
  bash scripts/setup-posix.sh install

# Assert + emit outputs
INPUT_VERSION=9.0.317 RUNNER_TOOL_CACHE=/tmp/dotnet-cache \
  bash scripts/setup-posix.sh finalize
```

`shasum -a 512` is used for verification (available on both macOS and Linux).

## Versioning and tags

- The moving `v1` tag points at the latest 1.x commit and is used by consumers
  (`devstroop/setup-dotnet@v1`). Force-push `v1` alongside a release.
- Keep `v1.x.y` tags immutable.
- Update `CHANGELOG.md` with each release.

## CI

Push to `main` triggers the self-test matrix in `.github/workflows/test.yml`
(9 runner/version combos). All must pass before tagging.

## Behavior notes

- The action is a composite script with no Node runtime by design — do not
  migrate it to a JavaScript action.
- Version resolution and the version assertion must stay exact: never fall
  back to an older version silently, and never skip SHA-512 verification
  (see `SECURITY.md`).
- .NET has no "current/latest overall release" concept: channels are the
  unit of versioning (`lts`/`sts`/line), and the SDK version is resolved per
  channel from `latest-sdk` or by searching `releases[].sdks[]` across
  channels (newest first) for exact versions.
- Always filter the release `files` list to `.tar.gz`/`.zip` — macOS
  entries with the `osx-*` rid also include installer formats (`.pkg`).