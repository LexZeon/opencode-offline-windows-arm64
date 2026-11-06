# Process-local environment example. Dot-source in a fresh terminal, then run
# your built CLI explicitly. This does not start a backend or install anything.
param(
    [Parameter(Mandatory = $true)][string]$StateRoot,
    [Parameter(Mandatory = $true)][string]$OfflineDependencies,
    [string]$Model = 'local-model',
    [string]$ApiBase = 'http://127.0.0.1:11434/v1'
)
$ErrorActionPreference = 'Stop'
$uri = $null
if (-not [Uri]::TryCreate($ApiBase, [UriKind]::Absolute, [ref]$uri) -or
    $uri.Scheme -notin @('http', 'https') -or $uri.Host -notin @('127.0.0.1', '[::1]', '::1') -or
    $uri.AbsolutePath.TrimEnd('/') -ne '/v1' -or $uri.UserInfo -or $uri.Query -or $uri.Fragment) {
    throw 'Use a literal loopback HTTP(S) API URL ending in /v1.'
}
foreach ($value in @($StateRoot, $OfflineDependencies)) {
    if (-not [IO.Path]::IsPathRooted($value) -or [IO.Path]::GetFullPath($value) -notmatch '^[A-Za-z]:\\.') {
        throw 'Use absolute local directory paths, not drive roots or network shares.'
    }
    $ancestor = [IO.Path]::GetFullPath($value)
    while (-not (Test-Path -LiteralPath $ancestor)) { $ancestor = Split-Path -Parent $ancestor }
    $item = Get-Item -LiteralPath $ancestor -Force
    while ($null -ne $item) {
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Do not use symlinks or junctions.' }
        $item = $item.Parent
    }
}
if (-not (Test-Path -LiteralPath $OfflineDependencies -PathType Container)) { throw 'Prepare the offline dependencies directory first.' }
if (Test-Path -LiteralPath $StateRoot) {
    if (@(Get-ChildItem -LiteralPath $StateRoot -Force).Count -ne 0) {
        throw 'For this example choose a new or empty state directory, separate from your usual OpenCode data.'
    }
}
foreach ($entry in @(Get-ChildItem Env: | Where-Object { $_.Name -like 'OPENCODE_*' })) {
    [Environment]::SetEnvironmentVariable($entry.Name, $null, 'Process')
}
$env:OPENCODE_LOCAL_MODEL = $Model
$env:OPENCODE_LOCAL_BASE_URL = $uri.AbsoluteUri.TrimEnd('/')
$env:OPENCODE_CONFIG = Join-Path $PSScriptRoot 'opencode.example.json'
$env:OPENCODE_OFFLINE_DEPS_PATH = [IO.Path]::GetFullPath($OfflineDependencies)
$env:OPENCODE_TEST_HOME = Join-Path $StateRoot 'home'
$env:OPENCODE_TEST_MANAGED_CONFIG_DIR = Join-Path $StateRoot 'managed-config'
$env:XDG_CONFIG_HOME = Join-Path $StateRoot 'config'
$env:XDG_DATA_HOME = Join-Path $StateRoot 'data'
$env:XDG_CACHE_HOME = Join-Path $StateRoot 'cache'
$env:XDG_STATE_HOME = Join-Path $StateRoot 'state'
$env:OPENCODE_CONFIG_DIR = Join-Path $env:XDG_CONFIG_HOME 'opencode'
foreach ($folder in @($env:OPENCODE_TEST_HOME, $env:OPENCODE_TEST_MANAGED_CONFIG_DIR,
    $env:XDG_CONFIG_HOME, $env:XDG_DATA_HOME, $env:XDG_CACHE_HOME, $env:XDG_STATE_HOME, $env:OPENCODE_CONFIG_DIR)) {
    [void][IO.Directory]::CreateDirectory($folder)
}
foreach ($name in @('OPENCODE_OFFLINE_MODE', 'OPENCODE_DISABLE_PROJECT_CONFIG',
    'OPENCODE_DISABLE_DEFAULT_PLUGINS', 'OPENCODE_DISABLE_MODELS_FETCH', 'OPENCODE_DISABLE_AUTOUPDATE',
    'OPENCODE_DISABLE_LSP_DOWNLOAD', 'OPENCODE_DISABLE_EXTERNAL_SKILLS', 'OPENCODE_DISABLE_CLAUDE_CODE',
    'OPENCODE_EXPERIMENTAL_DISABLE_FILEWATCHER')) {
    [Environment]::SetEnvironmentVariable($name, '1', 'Process')
}
$env:OPENCODE_ENABLE_EXA = '0'
$env:NPM_CONFIG_OFFLINE = 'true'
$env:NPM_CONFIG_AUDIT = 'false'
$env:NPM_CONFIG_FUND = 'false'
$env:NPM_CONFIG_IGNORE_SCRIPTS = 'true'
$env:NPM_CONFIG_UPDATE_NOTIFIER = 'false'
$env:HTTP_PROXY = 'http://127.0.0.1:1'
$env:HTTPS_PROXY = $env:HTTP_PROXY
$env:ALL_PROXY = $env:HTTP_PROXY
$env:NO_PROXY = 'localhost,127.0.0.1,::1'
Write-Host 'Example environment configured for this process only; no backend was started.'
