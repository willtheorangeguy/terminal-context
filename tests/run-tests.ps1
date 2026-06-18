#requires -Version 5.1
<#
.SYNOPSIS
  Build-and-behavior tests for the Open in Current Terminal handler.

.DESCRIPTION
  Static tests (always): build artifacts exist, the DLL exports the COM entry
  points, and it imports ONLY stable system DLLs (regression guard for the
  comctl32-v6 / VC-runtime load failures that hide the menu).

  Integration test (admin only): pack + register the MSIX and CoCreateInstance
  the handler CLSID to prove the DLL actually loads and the class factory works.
  Skipped automatically when not elevated, or with -SkipIntegration.
#>
[CmdletBinding()]
param(
    [string]$Configuration = "Release",
    [switch]$SkipIntegration
)

$ErrorActionPreference = "Stop"
$repo  = Split-Path -Parent $PSScriptRoot
$relDir = Join-Path $repo "build\$Configuration"
$clsid = "F4E9E6B5-DE73-45C8-BF95-BAB0532E1E17"

$script:Failed = 0
function Test-Case([string]$name, [scriptblock]$body) {
    try {
        & $body
        Write-Host "  [PASS] $name" -ForegroundColor Green
    } catch {
        Write-Host "  [FAIL] $name -- $_" -ForegroundColor Red
        $script:Failed++
    }
}
function Assert($cond, $msg) { if (-not $cond) { throw $msg } }

function Find-Dumpbin {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $hit = & $vswhere -latest -find "**\Hostx64\x64\dumpbin.exe" 2>$null |
           Select-Object -First 1
    if (-not $hit) { throw "dumpbin.exe not found." }
    return $hit
}

# --- Build -----------------------------------------------------------------
if (-not (Test-Path (Join-Path $relDir "ContextHandler.dll"))) {
    Write-Host "Building ($Configuration)..." -ForegroundColor Cyan
    cmake -S $repo -B (Join-Path $repo "build") -G "Visual Studio 17 2022" -A x64 | Out-Null
    cmake --build (Join-Path $repo "build") --config $Configuration | Out-Null
}

$dll = Join-Path $relDir "ContextHandler.dll"
$dumpbin = Find-Dumpbin

Write-Host "Static tests:" -ForegroundColor Cyan

Test-Case "build artifacts exist" {
    Assert (Test-Path $dll) "ContextHandler.dll missing"
    Assert (Test-Path (Join-Path $relDir "TerminalContextStub.exe")) "stub exe missing"
    Assert (Test-Path (Join-Path $repo "package\Assets\TerminalContext.ico")) "icon missing"
}

Test-Case "DLL exports COM entry points" {
    $exports = & $dumpbin /exports $dll
    Assert ($exports -match "DllGetClassObject") "DllGetClassObject not exported"
    Assert ($exports -match "DllCanUnloadNow")   "DllCanUnloadNow not exported"
}

Test-Case "DLL imports only stable system DLLs" {
    $deps = (& $dumpbin /dependents $dll) -join "`n"
    # These DLLs broke the handler before: comctl32 (v6-only TaskDialog) and the
    # VC runtime (not present in the COM surrogate). They must NOT be imported.
    foreach ($bad in "comctl32", "vcruntime", "msvcp", "api-ms-win-crt") {
        Assert ($deps -notmatch $bad) "DLL must not depend on '$bad'"
    }
    Assert ($deps -match "KERNEL32") "expected KERNEL32 import"
}

# --- Integration (admin only) ----------------------------------------------
$isAdmin = (New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole(
    [Security.Principal.WindowsBuiltinRole]::Administrator)

$appxAvailable = $true
try {
    Import-Module Appx -ErrorAction Stop
} catch {
    $appxAvailable = $false
}

if ($SkipIntegration -or -not $isAdmin) {
    Write-Host "Integration tests: SKIPPED (needs elevation)." -ForegroundColor Yellow
} elseif (-not $appxAvailable) {
    Write-Host "Integration tests: SKIPPED (Appx module unavailable on this platform)." -ForegroundColor Yellow
} else {
    Write-Host "Integration tests:" -ForegroundColor Cyan
    $pkgName = "TerminalContext.OpenInCurrentTerminal"
    $cleanup = {
        Get-AppxPackage -Name $pkgName -ErrorAction SilentlyContinue |
            Remove-AppxPackage -ErrorAction SilentlyContinue
    }
    try {
        & "$repo\tools\pack.ps1" -Configuration $Configuration -Version "0.0.1.0" `
            -OutDir "$repo\dist\test" | Out-Null
        $msix = Get-ChildItem "$repo\dist\test\*.msix" | Select-Object -First 1
        $cer  = Get-ChildItem "$repo\dist\test\*.cer"  | Select-Object -First 1
        Import-Certificate -FilePath $cer.FullName -CertStoreLocation Cert:\LocalMachine\Root | Out-Null

        Test-Case "MSIX registers" {
            Add-AppxPackage -Path $msix.FullName -ForceUpdateFromAnyVersion
            Assert (Get-AppxPackage -Name $pkgName) "package not registered"
        }

        Test-Case "handler CLSID activates (DLL loads + class factory works)" {
            $type = [type]::GetTypeFromCLSID([guid]$clsid, $true)
            $obj = [activator]::CreateInstance($type)
            Assert ($null -ne $obj) "CoCreateInstance returned null"
            [Runtime.InteropServices.Marshal]::ReleaseComObject($obj) | Out-Null
        }
    } finally {
        & $cleanup
    }
}

Write-Host ""
if ($script:Failed -gt 0) {
    Write-Host "$($script:Failed) test(s) failed." -ForegroundColor Red
    exit 1
}
Write-Host "All tests passed." -ForegroundColor Green
