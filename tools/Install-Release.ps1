#requires -Version 5.1
<#
.SYNOPSIS
  Install "Open in Current Terminal" from a release download (.msix + .cer).

.DESCRIPTION
  Run elevated. Trusts the bundled signing certificate (LocalMachine) and
  registers the MSIX. Auto-detects the .msix and .cer next to this script.
#>
[CmdletBinding()]
param(
    [string]$Msix,
    [string]$Cert
)

$ErrorActionPreference = "Stop"

$id = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltinRole]::Administrator)) {
    throw "Run this script from an elevated (Administrator) PowerShell window."
}

if (-not $Msix) {
    $Msix = (Get-ChildItem -Path $PSScriptRoot -Filter *.msix |
             Select-Object -First 1).FullName
}
if (-not $Cert) {
    $Cert = (Get-ChildItem -Path $PSScriptRoot -Filter *.cer |
             Select-Object -First 1).FullName
}
if (-not $Msix) { throw "No .msix found. Pass -Msix <path>." }
if (-not $Cert) { throw "No .cer found. Pass -Cert <path>." }

Write-Host "Trusting certificate $Cert ..." -ForegroundColor Cyan
Import-Certificate -FilePath $Cert -CertStoreLocation Cert:\LocalMachine\Root        | Out-Null
Import-Certificate -FilePath $Cert -CertStoreLocation Cert:\LocalMachine\TrustedPeople | Out-Null

Write-Host "Registering $Msix ..." -ForegroundColor Cyan
Add-AppxPackage -Path $Msix -ForceUpdateFromAnyVersion

Write-Host ""
Write-Host "Installed. Restart Explorer to refresh the context menu:" -ForegroundColor Green
Write-Host "  Stop-Process -Name explorer -Force"
