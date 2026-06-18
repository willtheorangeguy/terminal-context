# Open in Current Terminal

A Windows 11 File Explorer context-menu entry — **"Open in Current Terminal"** —
that opens the right-clicked folder as a **new tab in your already-open Windows
Terminal window** instead of spawning a fresh terminal. When several terminal
windows are open it shows a chooser; the selected window is raised and the new
(auto-focused) tab appears in it.

Appears in the **main** Windows 11 right-click menu (not buried under "Show more
options"), on both folders and folder backgrounds.

## How it works

A single in-process COM DLL (`ContextHandler.dll`) implements `IExplorerCommand`
and is registered through a **sparse MSIX package** (which is what grants a
top-level Win11 menu entry). On click it:

1. reads the folder path from the shell selection;
2. enumerates open Windows Terminal windows (`CASCADIA_HOSTING_WINDOW_CLASS`,
   owned by `WindowsTerminal.exe`);
3. picks the window — directly if one, via a `TaskDialog` chooser if several,
   or opens a new window if none;
4. brings it to the foreground and runs `wt -w 0 new-tab -d "<folder>"`.

Why a new tab: Windows Terminal has **no API to run a command in an existing
tab**, so `cd`-ing the current tab isn't possible. Opening a new tab in the
existing window (`wt -w 0 new-tab -d`) is the official, reliable path. `-w 0`
targets the most-recently-used window, so the handler focuses the chosen window
first.

## Layout

```
src/                 C++ COM handler (no external deps)
  Guid.h             CLSID
  dllmain.cpp        exports + class factory
  ContextCommand.*   IExplorerCommand implementation
  TerminalLauncher.* window enumeration, chooser, wt launch
  stub.cpp           placeholder exe required by the package
package/             sparse MSIX manifest + icon assets
tools/               install.ps1 / uninstall.ps1
CMakeLists.txt
```

## Install from a release

Download the latest `OpenInCurrentTerminal_*.zip` from
[Releases](../../releases), extract it, then from an **elevated** PowerShell:

```powershell
.\Install-Release.ps1            # trusts the bundled cert + registers the MSIX
Stop-Process -Name explorer -Force
```

The package is signed with a self-signed certificate; `Install-Release.ps1`
trusts it (LocalMachine) so Windows will sideload the MSIX. Uninstall any time:
`Get-AppxPackage *OpenInCurrentTerminal* | Remove-AppxPackage`.

> Why an MSIX and not an .exe/.msi installer? A top-level Windows 11 context-menu
> entry must be provided by a packaged `IExplorerCommand` COM handler. Only MSIX
> grants the package identity that registration requires; a classic MSI/EXE can't.

## Build + install (from source)

Requirements: Visual Studio 2022 (MSVC + C++), Windows 11 SDK, CMake.

```powershell
# From an ELEVATED PowerShell window (cert trust writes to LocalMachine):
.\tools\install.ps1
Stop-Process -Name explorer -Force   # refresh the shell
```

`install.ps1` builds the DLL, stages a sparse package (binaries kept at an
external location), creates and trusts a self-signed code-signing cert, signs the
package, and registers it with `Add-AppxPackage -ExternalLocation`.

> Note: the installed binaries are served from `dist\ext\` in this repo — keep
> that folder in place, or move it and re-run install.

## Tests

```powershell
.\tests\run-tests.ps1          # static checks; run elevated for integration tests
```

Static tests verify the build artifacts, the DLL's COM exports, and that it
imports only stable system DLLs (a regression guard for the comctl32-v6 /
VC-runtime load failures that silently hide the menu). Run elevated to also pack,
register, and activate the handler CLSID. CI runs these on every push/PR
(`.github/workflows/ci.yml`); `build.yml` compiles and validates the MSIX.

## Releasing

Publishing a GitHub release (tag `vX.Y.Z`) triggers `.github/workflows/release.yml`,
which builds x64 Release, packs a signed self-contained MSIX via `tools/pack.ps1`,
and attaches the `.msix`, `.cer`, and a `.zip` bundle to the release. To build a
release artifact locally: `./tools/pack.ps1 -Version 1.2.3.0`.

> The CI signs with a self-signed cert generated on the runner. For a smoother
> end-user experience, swap in a real code-signing certificate (store the PFX in
> repo secrets and adjust `pack.ps1`/the workflow to use it).

## Uninstall

```powershell
.\tools\uninstall.ps1                 # elevated
Stop-Process -Name explorer -Force
```

## Caveats

- Always opens a **new tab**, never the literal current tab (Windows Terminal
  limitation).
- The chooser runs in a COM surrogate; if you click away before it appears,
  Windows foreground rules may briefly prevent the window from raising.
- Self-signed = sideloading. To use on another machine, install the same cert in
  its LocalMachine Trusted Root, or sign with a real code-signing certificate.
