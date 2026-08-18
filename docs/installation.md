# Open in Current Terminal — Installation

Two routes: a signed release bundle, or a build from source. Both need elevation, and both need
Explorer restarted afterwards.

## From a release

1. Download `OpenInCurrentTerminal_*.zip` from
   [Releases](https://github.com/willtheorangeguy/terminal-context/releases) and extract it.
2. From an **elevated** PowerShell:

```powershell
.\Install-Release.ps1
Stop-Process -Name explorer -Force
```

`Install-Release.ps1` trusts the bundled certificate (LocalMachine) and registers the MSIX.

The bundle contains the `.msix`, the `.cer`, and the script.

## From source

**Requirements:** Visual Studio 2022 with the MSVC C++ workload, the Windows 11 SDK, CMake.

```powershell
# elevated — the certificate trust writes to LocalMachine
.\tools\install.ps1
Stop-Process -Name explorer -Force
```

`install.ps1` builds the DLL, stages a **sparse** package, creates and trusts a self-signed
code-signing certificate, signs the package, and registers it with
`Add-AppxPackage -ExternalLocation`.

> **The binaries stay in the repository.** A sparse package registers identity with Windows while
> the actual files are served from `dist\ext\` in your working copy. Move, rename, or delete that
> folder and the installed handler breaks — with no error, just a menu entry that stops working.
> Re-run `install.ps1` after relocating the repository.

## Why an MSIX

A top-level Windows 11 context-menu entry has to come from a packaged `IExplorerCommand` COM
handler. The registration requires **package identity**, and only MSIX grants it. A classic
MSI or EXE installer cannot provide one at all — so there is no lighter option, only a
lower-priority menu entry under "Show more options".

## Why a certificate

Windows will not sideload an unsigned MSIX. The self-signed certificate exists to satisfy that,
not to assure anyone of anything — which is why installing it means adding a certificate you
generated to your machine's trusted roots.

For another machine, either install the same certificate into its LocalMachine trusted root
store, or sign with a real code-signing certificate. See [Deployment](./deployment.md).

## Verify

```powershell
Get-AppxPackage *OpenInCurrentTerminal*
```

Then right-click a folder. If the package is registered and the entry is missing, the DLL failed
to load inside Explorer — see [Troubleshooting](./troubleshooting.md).

## Uninstall

```powershell
.\tools\uninstall.ps1              # elevated
# or
Get-AppxPackage *OpenInCurrentTerminal* | Remove-AppxPackage

Stop-Process -Name explorer -Force
```

Removing the package does not remove the certificate from your trusted roots. Delete it from
`certlm.msc` if you want it gone.
