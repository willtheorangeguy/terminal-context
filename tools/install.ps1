#requires -Version 5.1
<#
.SYNOPSIS
  Build, sign, and register the "Open in Current Terminal" context-menu handler
  as a sparse MSIX package with external content.

.DESCRIPTION
  Must run elevated: trusting the self-signed signing certificate writes to the
  LocalMachine certificate store, which sideloading requires.
#>
[CmdletBinding()]
param(
    [string]$Configuration = "Release",
    [string]$CertSubject   = "CN=TerminalContextDev"
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot

# Log everything so failures can be diagnosed after the fact.
$logDir = Join-Path $repo "dist"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
Start-Transcript -Path (Join-Path $logDir "install.log") -Force | Out-Null
trap { Write-Host "INSTALL FAILED: $_" -ForegroundColor Red; Stop-Transcript | Out-Null; break }

function Assert-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $p.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        throw "Run this script from an elevated (Administrator) PowerShell window."
    }
}

function Find-SdkTool($name) {
    $base = "C:\Program Files (x86)\Windows Kits\10\bin"
    $tool = Get-ChildItem "$base\*\x64\$name" -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending | Select-Object -First 1
    if (-not $tool) { throw "Could not find $name under $base." }
    return $tool.FullName
}

Assert-Admin

$makeappx = Find-SdkTool "makeappx.exe"
$signtool = Find-SdkTool "signtool.exe"
$buildDir = Join-Path $repo "build"
$relDir   = Join-Path $buildDir $Configuration

# 1. Build the DLL + stub if missing.
if (-not (Test-Path (Join-Path $relDir "ContextHandler.dll"))) {
    Write-Host "Building ($Configuration)..." -ForegroundColor Cyan
    cmake -S $repo -B $buildDir -G "Visual Studio 17 2022" -A x64 | Out-Null
    cmake --build $buildDir --config $Configuration | Out-Null
}

# 2. Stage layout: package content (manifest + assets) and external content (binaries).
$dist = Join-Path $repo "dist"
$pkgDir = Join-Path $dist "pkg"
$extDir = Join-Path $dist "ext"
Remove-Item $dist -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $pkgDir, $extDir | Out-Null

Copy-Item (Join-Path $repo "package\AppxManifest.xml") $pkgDir
Copy-Item (Join-Path $repo "package\Assets") $pkgDir -Recurse
Copy-Item (Join-Path $relDir "ContextHandler.dll")       $extDir
Copy-Item (Join-Path $relDir "TerminalContextStub.exe")  $extDir
Copy-Item (Join-Path $repo "package\Assets\TerminalContext.ico") $extDir

# 3. Pack the sparse package (binaries live at the external location).
$msix = Join-Path $dist "TerminalContext.msix"
& $makeappx pack /o /d $pkgDir /p $msix /nv
if ($LASTEXITCODE -ne 0) { throw "makeappx failed ($LASTEXITCODE)." }

# 4. Ensure a self-signed code-signing cert matching the manifest Publisher.
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

# Trust it for package validation (LocalMachine Trusted Root + Trusted People).
$cerPath = Join-Path $dist "TerminalContext.cer"
Export-Certificate -Cert $cert -FilePath $cerPath -Force | Out-Null
Import-Certificate -FilePath $cerPath -CertStoreLocation Cert:\LocalMachine\Root        | Out-Null
Import-Certificate -FilePath $cerPath -CertStoreLocation Cert:\LocalMachine\TrustedPeople | Out-Null

# 5. Sign the package.
& $signtool sign /fd SHA256 /sha1 $cert.Thumbprint $msix
if ($LASTEXITCODE -ne 0) { throw "signtool failed ($LASTEXITCODE)." }

# 6. Register the package with its external content location.
Write-Host "Registering package (external location: $extDir)..." -ForegroundColor Cyan
Add-AppxPackage -Path $msix -ExternalLocation $extDir -ForceUpdateFromAnyVersion -Verbose

# 7. Verify.
$pkg = Get-AppxPackage -Name "TerminalContext.OpenInCurrentTerminal"
if (-not $pkg) { throw "Package did not register." }
Write-Host "Registered: $($pkg.PackageFullName)  Status=$($pkg.Status)" -ForegroundColor Green

Write-Host ""
Write-Host "Installed. Restart Explorer to refresh the context menu:" -ForegroundColor Green
Write-Host "  Stop-Process -Name explorer -Force" -ForegroundColor Green
Write-Host "Right-click a folder (or empty space in a folder) -> 'Open in Current Terminal'."
Stop-Transcript | Out-Null
