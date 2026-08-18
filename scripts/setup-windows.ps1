# setup-windows.ps1 — install the .NET SDK archive on Windows.
# (resolve + finalize run in Git Bash on Windows; only the download/extract
# lives here.)
#
# env: RESOLVED_VERSION, INSTALL_ROOT, ARCHIVE_URL, SHA512, CACHE_HIT, GITHUB_PATH
#   INSTALL_ROOT is emitted by setup-posix.sh resolve (forward slashes).

$ErrorActionPreference = "Stop"

$dotnetExe = Join-Path $env:INSTALL_ROOT "dotnet.exe"

if ($env:CACHE_HIT -eq "true" -and (Test-Path $dotnetExe)) {
    Write-Host ".NET SDK restored from cache at $env:INSTALL_ROOT"
} else {
    New-Item -ItemType Directory -Force -Path $env:INSTALL_ROOT | Out-Null

    $archive = Join-Path $env:INSTALL_ROOT "dotnet.archive"
    Write-Host "Downloading $env:ARCHIVE_URL"
    curl.exe -fL --retry 3 --retry-delay 5 -o $archive $env:ARCHIVE_URL
    if ($LASTEXITCODE -ne 0) { throw "download failed: $env:ARCHIVE_URL" }

    $got = (Get-FileHash -Algorithm SHA512 -Path $archive).Hash.ToLowerInvariant()
    $want = $env:SHA512.ToLowerInvariant()
    if ($got -ne $want) {
        throw "SHA-512 mismatch for $(Split-Path $env:ARCHIVE_URL -Leaf): got $got, expected $want"
    }
    Write-Host "SHA-512 verified"

    if ($env:ARCHIVE_URL -like "*.zip") {
        # Some archives contain a top-level dotnet-sdk-X/ dir; move any such
        # dir's contents up so the SDK lands directly in INSTALL_ROOT.
        $expanded = Join-Path $env:INSTALL_ROOT "expanded"
        Expand-Archive -Path $archive -DestinationPath $expanded -Force
        $inner = Get-ChildItem -Path $expanded -Directory | Select-Object -First 1
        $src = if ($inner) { $inner.FullName } else { $expanded }
        Get-ChildItem -Path $src -Force | Move-Item -Destination $env:INSTALL_ROOT -Force
        Remove-Item $expanded -Recurse -Force
        Remove-Item $archive -Force
    } else {
        throw "unsupported archive format: $env:ARCHIVE_URL"
    }

    if (-not (Test-Path $dotnetExe)) {
        throw "archive did not contain dotnet.exe at $env:INSTALL_ROOT"
    }
    Write-Host ".NET SDK installed at $env:INSTALL_ROOT"
}

Add-Content -Path $env:GITHUB_PATH -Value $env:INSTALL_ROOT
Write-Host "Added $env:INSTALL_ROOT to PATH"