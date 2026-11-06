#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$WorkDirectory,
    [string]$BunArchivePath,
    [switch]$PlanOnly
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$sourceUrl = 'https://github.com/Chetic/opencode-offline.git'
$sourceCommit = 'bcdbd58d57c1c38b13b3f9a3d8b423786f0e1d85'
$bunVersion = '1.4.4'
$bunUrl = 'https://github.com/oven-sh/bun/releases/download/bun-v1.4.4/bun-windows-aarch64.zip'
$bunArchiveSha256 = '2d57a0eec0cb44d95c918c3f9734f60455a1306ae5085d76fc68f44e3ee30d09'
$patchSha256 = 'ab6fdac13064c35830493f10227995a1c899c5fd55f6bb0d2ea9508e3c0f2a05'
$packageRoot = Split-Path -Parent $PSScriptRoot
$patchPath = Join-Path $packageRoot 'patches\windows-arm64-offline.patch'

function Get-LocalDirectoryPath([string]$Value) {
    if (-not [IO.Path]::IsPathRooted($Value)) { throw 'WorkDirectory must be an absolute local path.' }
    $full = [IO.Path]::GetFullPath($Value).TrimEnd('\')
    if ($full -notmatch '^[A-Za-z]:\\.' -or
        [IO.DriveInfo]::new([IO.Path]::GetPathRoot($full)).DriveType -ne [IO.DriveType]::Fixed) {
        throw 'Use a folder on a local fixed drive, not a drive root or network share.'
    }
    $ancestor = $full
    while (-not (Test-Path -LiteralPath $ancestor)) { $ancestor = Split-Path -Parent $ancestor }
    $item = Get-Item -LiteralPath $ancestor -Force
    if (-not $item.PSIsContainer) { throw 'A path component is a file.' }
    while ($null -ne $item) {
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw 'WorkDirectory must not contain symlinks, junctions or reparse points.'
        }
        $item = $item.Parent
    }
    return $full
}

function Invoke-Checked([string]$FilePath, [string[]]$ArgumentList) {
    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) { throw "Command failed with exit code ${LASTEXITCODE}: $FilePath" }
}

function Get-PeMachine([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $reader = [IO.BinaryReader]::new($stream)
    try {
        if ($reader.ReadUInt16() -ne 0x5A4D) { throw 'Not a Windows executable.' }
        $stream.Position = 0x3C
        $offset = $reader.ReadInt32()
        $stream.Position = $offset
        if ($reader.ReadUInt32() -ne 0x00004550) { throw 'Invalid PE header.' }
        return $reader.ReadUInt16()
    } finally { $reader.Dispose(); $stream.Dispose() }
}

$work = Get-LocalDirectoryPath $WorkDirectory
if (Test-Path -LiteralPath $work) {
    if (@(Get-ChildItem -LiteralPath $work -Force).Count -ne 0) {
        throw 'WorkDirectory must be new or empty. Existing files are never removed.'
    }
}
if (-not (Test-Path -LiteralPath $patchPath -PathType Leaf)) { throw 'The pinned source patch is missing.' }
if ((Get-FileHash -LiteralPath $patchPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $patchSha256) {
    throw 'Source patch SHA256 differs from this build recipe.'
}
$git = (Get-Command git.exe -ErrorAction Stop).Source
if ($PlanOnly) {
    [pscustomobject]@{
        Source = $sourceUrl; Commit = $sourceCommit; Bun = $bunVersion
        PatchSHA256 = $patchSha256; NativeTarget = 'bun-windows-arm64'
        Actions = @('clone into a new work directory', 'checkout pinned commit', 'git apply --check then apply patch',
            'verify official Bun archive SHA256', 'bun install --frozen-lockfile',
            'bun run script/build.ts --single --skip-install', 'bun run --cwd packages/app build')
        Downloads = 'Git source, verified Bun archive and npm build dependencies only; no models'
    } | ConvertTo-Json -Depth 4
    return
}
if ($env:OS -ne 'Windows_NT') { throw 'This recipe targets Windows ARM64.' }
$osArm64 = $env:PROCESSOR_ARCHITECTURE -eq 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -eq 'ARM64'
try { $osArm64 = $osArm64 -or [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() -eq 'Arm64' } catch {}
if (-not $osArm64) { throw 'Use Windows on ARM64. Cross-compilation and emulation are not this recipe.' }

[void][IO.Directory]::CreateDirectory($work)
$source = Join-Path $work 'source'
$toolchain = Join-Path $work 'toolchain'
[void][IO.Directory]::CreateDirectory($toolchain)
Invoke-Checked $git @('clone', '--no-checkout', '--filter=blob:none', '--', $sourceUrl, $source)
Invoke-Checked $git @('-C', $source, 'checkout', '--detach', $sourceCommit)
$head = (& $git -C $source rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $head -ne $sourceCommit) { throw 'Pinned checkout verification failed.' }
Invoke-Checked $git @('-C', $source, 'apply', '--check', '--', $patchPath)
Invoke-Checked $git @('-C', $source, 'apply', '--', $patchPath)

if ($BunArchivePath) {
    $archive = (Get-Item -LiteralPath $BunArchivePath -ErrorAction Stop).FullName
} else {
    $archive = Join-Path $toolchain 'bun-windows-aarch64.zip'
    $oldTls = [Net.ServicePointManager]::SecurityProtocol
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -UseBasicParsing -Uri $bunUrl -OutFile $archive
    } finally { [Net.ServicePointManager]::SecurityProtocol = $oldTls }
}
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $bunArchiveSha256) {
    throw 'Bun archive SHA256 verification failed; no archive content was executed.'
}
$expanded = Join-Path $toolchain 'bun-1.4.4'
Expand-Archive -LiteralPath $archive -DestinationPath $expanded
$bun = Join-Path $expanded 'bun-windows-aarch64\bun.exe'
if ((Get-PeMachine $bun) -ne 0xAA64) { throw 'Expected native ARM64 Bun.' }
$actualVersion = (& $bun --version).Trim()
if ($LASTEXITCODE -ne 0 -or $actualVersion -ne $bunVersion) { throw 'Unexpected Bun version.' }
$actualArch = (& $bun -p 'process.arch').Trim()
if ($LASTEXITCODE -ne 0 -or $actualArch -ne 'arm64') { throw 'Bun is not executing natively as ARM64.' }

$savedEnvironment = @{}
$changes = @{
    PATH = (Split-Path -Parent $bun) + ';' + $env:PATH
    BUN_INSTALL_CACHE_DIR = (Join-Path $work 'cache\bun')
    HUSKY = '0'
    OPENCODE_VERSION = '1.2.13'
    OPENCODE_CHANNEL = 'local'
    OPENCODE_RELEASE = $null
    MODELS_DEV_API_JSON = (Join-Path $work 'models-snapshot.json')
}
# Build a custom-provider-only model registry; no models.dev request is needed.
[IO.File]::WriteAllText($changes.MODELS_DEV_API_JSON, '{}', [Text.UTF8Encoding]::new($false))
try {
    foreach ($name in $changes.Keys) {
        $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
        [Environment]::SetEnvironmentVariable($name, $changes[$name], 'Process')
    }
    Push-Location -LiteralPath $source
    try {
        Invoke-Checked $bun @('install', '--frozen-lockfile')
        Push-Location -LiteralPath (Join-Path $source 'packages\opencode')
        try { Invoke-Checked $bun @('run', 'script/build.ts', '--single', '--skip-install') }
        finally { Pop-Location }
        Invoke-Checked $bun @('run', '--cwd', 'packages/app', 'build')
    } finally { Pop-Location }
} finally {
    foreach ($name in $savedEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process')
    }
}
$cli = Join-Path $source 'packages\opencode\dist\opencode-windows-arm64\bin\opencode.exe'
$web = Join-Path $source 'packages\app\dist'
if ((Get-PeMachine $cli) -ne 0xAA64 -or -not (Test-Path -LiteralPath (Join-Path $web 'index.html'))) {
    throw 'Expected native CLI and web build outputs were not produced.'
}
$receipt = [ordered]@{
    source = $sourceUrl; commit = $sourceCommit; patch_sha256 = $patchSha256
    bun_version = $bunVersion; bun_archive_sha256 = $bunArchiveSha256; native_architecture = 'ARM64'
    cli = 'source/packages/opencode/dist/opencode-windows-arm64/bin/opencode.exe'
    web = 'source/packages/app/dist'; runtime_started = $false; models_downloaded = $false
    built_at_utc = [DateTime]::UtcNow.ToString('o')
}
$receipt | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $work 'build-receipt.json') -Encoding UTF8
Write-Host "Native CLI: $cli"
Write-Host "Local web assets: $web"
Write-Host 'Build completed. Runtime, MCP, model and offline deployment checks are separate; see VERIFICATION.md.'
