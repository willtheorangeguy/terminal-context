#requires -Version 5.1
<#
.SYNOPSIS
  Build the handler and produce a self-contained, signed MSIX for distribution.

.DESCRIPTION
  Unlike tools/install.ps1 (which registers a sparse package with external
  content for local development), this produces a full MSIX with the binaries
  packed inside it -- the form you ship on a GitHub release. Signs with a
  self-signed certificate by default and exports the public .cer next to it so
  users can trust and sideload the package.

.PARAMETER Version
  Four-part package version (e.g. 1.2.3.0). Substituted into the manifest.

.PARAMETER OutDir
  Where the .msix and .cer are written. Defaults to <repo>\release.
#>
[CmdletBinding()]
param(
    [string]$Configuration = "Release",
    [string]$Version       = "1.0.0.0",
    [string]$OutDir        = "",
    [string]$CertSubject   = "CN=TerminalContextDev"
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
if (-not $OutDir) { $OutDir = Join-Path $repo "release" }

function Find-SdkTool($name) {
    $base = "C:\Program Files (x86)\Windows Kits\10\bin"
    $tool = Get-ChildItem "$base\*\x64\$name" -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending | Select-Object -First 1
    if (-not $tool) { throw "Could not find $name under $base." }
    return $tool.FullName
}

$makeappx = Find-SdkTool "makeappx.exe"
$signtool = Find-SdkTool "signtool.exe"
$buildDir = Join-Path $repo "build"
$relDir   = Join-Path $buildDir $Configuration

# 1. Build the DLL + stub.
if (-not (Test-Path (Join-Path $relDir "ContextHandler.dll"))) {
    Write-Host "Building ($Configuration)..." -ForegroundColor Cyan
    cmake -S $repo -B $buildDir -G "Visual Studio 17 2022" -A x64 | Out-Null
    cmake --build $buildDir --config $Configuration | Out-Null
}

# 2. Stage a self-contained package layout (manifest + assets + binaries).
$stage = Join-Path $repo "dist\msix"
Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $stage, $OutDir | Out-Null

# Manifest with the requested version, and external-content turned off (binaries
# are inside this package).
$manifest = Get-Content (Join-Path $repo "package\AppxManifest.xml") -Raw
$manifest = $manifest -replace 'Version="1\.0\.0\.0"', "Version=`"$Version`""
$manifest = $manifest -replace '\s*<uap10:AllowExternalContent>true</uap10:AllowExternalContent>', ''
Set-Content -Path (Join-Path $stage "AppxManifest.xml") -Value $manifest -Encoding UTF8

Copy-Item (Join-Path $repo "package\Assets") $stage -Recurse
Copy-Item (Join-Path $relDir "ContextHandler.dll")              $stage
Copy-Item (Join-Path $relDir "TerminalContextStub.exe")         $stage
Copy-Item (Join-Path $repo "package\Assets\TerminalContext.ico") $stage

# 3. Pack.
$msix = Join-Path $OutDir "OpenInCurrentTerminal_${Version}_x64.msix"
& $makeappx pack /o /d $stage /p $msix
if ($LASTEXITCODE -ne 0) { throw "makeappx failed ($LASTEXITCODE)." }

# 4. Self-signed cert matching the manifest Publisher.
$cert = Get-ChildItem Cert:\CurrentUser\My |
        Where-Object { $_.Subject -eq $CertSubject } | Select-Object -First 1
if (-not $cert) {
    Write-Host "Creating self-signed certificate $CertSubject ..." -ForegroundColor Cyan
    $cert = New-SelfSignedCertificate -Type Custom -Subject $CertSubject `
        -KeyUsage DigitalSignature -FriendlyName "Terminal Context Dev" `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3",
                         "2.5.29.19={text}")
}
$cer = Join-Path $OutDir "OpenInCurrentTerminal.cer"
Export-Certificate -Cert $cert -FilePath $cer -Force | Out-Null

# 5. Sign.
& $signtool sign /fd SHA256 /sha1 $cert.Thumbprint $msix
if ($LASTEXITCODE -ne 0) { throw "signtool failed ($LASTEXITCODE)." }

Write-Host ""
Write-Host "Packaged:" -ForegroundColor Green
Write-Host "  $msix"
Write-Host "  $cer"
