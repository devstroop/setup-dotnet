# Setup .NET

GitHub Action that installs a pinned .NET SDK from the official dotnetcli
release metadata (SHA-512 verified), exposes it on `PATH`, and exports
`DOTNET_ROOT` for the rest of the job.

Pure bash + Python — no Node runtime, no third-party actions for the setup
itself (only `actions/cache` for the tiered toolchain caching).

## Inputs

| Input       | Default  | Description |
|-------------|----------|-------------|
| `version`   | `lts`    | `lts` / `sts` / `latest` channel, a channel line like `9.0` (latest SDK on that channel), or an exact SDK version like `9.0.317` |
| `use-cache` | `true`   | Cache the SDK between runs |
| `cache-key` | ``       | Extra cache key component (recommend `${{ matrix.name }}` in matrices) |

## Outputs

| Output          | Description |
|-----------------|-------------|
| `dotnet-version` | Resolved SDK version (e.g. `10.0.400`) |
| `dotnet-root`    | SDK root (contains the `dotnet` binary, `sdk/`, `shared/`) |
| `cache-hit`      | Whether the SDK was restored from cache |

## Usage

```yaml
- uses: devstroop/setup-dotnet@v1
  with:
    version: '9.0'           # or '9.0.317', 'lts', 'sts', 'latest'
    cache-key: linux-arm64   # recommended in matrices

- run: dotnet --version
- run: dotnet build
- run: dotnet test
```

Version semantics (mirrors `setup-node` / `setup-flutter`):

- `lts` — newest supported LTS channel (default)
- `sts` — newest supported STS channel
- `latest` — newest non-preview channel
- `9.0` — latest SDK on the 9.0 channel line
- `9.0.317` — exact SDK version (searched across channels, newest first)

The archive is picked from the release metadata's `files` list by the
runner's `os`/`arch` (installer formats like `.pkg`/`.msi` are excluded).

## Caching

Keyed by exact resolved SDK version:
`setup-dotnet-${{ runner.os }}-${{ runner.arch }}-<version>__<cache-key>`.

No `restore-keys` fallback is used: restoring an older SDK into the resolved
version's directory would fail the version assertion in the finalize step
(and with `version: lts` the resolved version changes over time). Cache
misses add a few seconds to a minute (archive is ~200 MB); subsequent runs
with the same version restore instantly.

## Notes

- Windows uses `scripts/setup-windows.ps1` for install; resolution and the
  version assertion still run in Git Bash so behavior is identical across OSes.
- The version assertion runs `dotnet --version` from the install root, so a
  `global.json` in the repo root cannot skew it.
- `DOTNET_ROOT` is exported and the SDK root is prepended to `PATH`.
- Self-tests live in `.github/workflows/test.yml` (channel / line / exact
  resolution, SHA-512 verification, version assertion, smoke app).

## License

MIT