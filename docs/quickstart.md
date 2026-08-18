# Open in Current Terminal — Quickstart

## Install from a release

Download the latest `OpenInCurrentTerminal_*.zip` from
[Releases](https://github.com/willtheorangeguy/terminal-context/releases) and extract it.

From an **elevated** PowerShell:

```powershell
.\Install-Release.ps1
Stop-Process -Name explorer -Force
```

Elevation is needed because the script writes the bundled certificate to the LocalMachine
trusted store — Windows will not sideload an MSIX signed by a certificate it does not trust.

Restarting Explorer is what makes the new menu entry appear.

## Use it

Right-click **a folder**, or **the background of an open folder**, and choose
**Open in Current Terminal**. It sits in the main Windows 11 menu, not under "Show more
options".

| Terminal windows open | What happens |
|---|---|
| None | A new Windows Terminal window opens at that folder |
| One | A new tab opens in it, and the window is raised |
| Several | A chooser lists them; the one you pick is raised and gets the tab |

It is always a **new tab**, never the tab you are looking at. Windows Terminal provides no way
to do the latter — see [FAQ](./faq.md).

## Uninstall

```powershell
Get-AppxPackage *OpenInCurrentTerminal* | Remove-AppxPackage
Stop-Process -Name explorer -Force
```

Or `.\tools\uninstall.ps1` from an elevated prompt if you installed from source.

## If the entry does not appear

Almost always one of three things:

1. Explorer was not restarted.
2. The MSIX did not register — `Get-AppxPackage *OpenInCurrentTerminal*` returns nothing.
3. The DLL failed to load inside Explorer, which produces **no error at all** and simply hides
   the entry.

[Troubleshooting](./troubleshooting.md) walks through each.

## From source

```powershell
# elevated
.\tools\install.ps1
Stop-Process -Name explorer -Force
```

Requires Visual Studio 2022 with the C++ workload, the Windows 11 SDK, and CMake. Note that a
source install serves its binaries from `dist\ext\` **in the repository** — moving or deleting
that folder breaks the installed handler. See [Installation](./installation.md).
