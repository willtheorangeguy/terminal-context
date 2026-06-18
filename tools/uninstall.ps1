#requires -Version 5.1
<#
.SYNOPSIS
  Unregister the context-menu package and remove the self-signed certificate.
#>
[CmdletBinding()]
param(
    [string]$PackageName = "TerminalContext.OpenInCurrentTerminal",
    [string]$CertSubject = "CN=TerminalContextDev"
)

$ErrorActionPreference = "Continue"

$pkg = Get-AppxPackage -Name $PackageName
if ($pkg) {
    Remove-AppxPackage -Package $pkg.PackageFullName
    Write-Host "Removed package $($pkg.PackageFullName)." -ForegroundColor Green
} else {
    Write-Host "Package $PackageName not installed." -ForegroundColor Yellow
}

foreach ($store in "Cert:\LocalMachine\Root", "Cert:\LocalMachine\TrustedPeople",
                   "Cert:\CurrentUser\My") {
    Get-ChildItem $store -ErrorAction SilentlyContinue |
        Where-Object { $_.Subject -eq $CertSubject } |
        ForEach-Object {
            Remove-Item $_.PSPath -Force -ErrorAction SilentlyContinue
            Write-Host "Removed cert from $store." -ForegroundColor Green
        }
}

Write-Host "Restart Explorer to drop the menu entry: Stop-Process -Name explorer -Force"
