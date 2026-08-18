# Open in Current Terminal — Troubleshooting

## The menu entry does not appear

Work through these in order — they are ordered by how often each is the cause.

**1. Restart Explorer.**

```powershell
Stop-Process -Name explorer -Force
```

Explorer caches context-menu registrations. A fresh install does nothing until it restarts.

**2. Confirm the package is registered.**

```powershell
Get-AppxPackage *OpenInCurrentTerminal*
```

Nothing returned means registration failed or was undone. Re-run the install from an **elevated**
prompt.

**3. Confirm the DLL loads.**

This is the case with no error message anywhere. From an elevated PowerShell:

```powershell
.\tests\run-tests.ps1
```

The integration test `CoCreateInstance`s the handler CLSID. If it fails, the DLL is not loading —
almost always a dependency that is missing or the wrong version. The static import check in the
same script names the culprit.

The reason this is silent: Explorer asks a COM surrogate to create the handler, gets a failure,
and omits the entry. There is no dialog and no event log entry.

**4. Confirm you are on Windows 11.** The manifest requires 10.0.22000 or later.

## The entry appears but nothing happens

| Cause | Check |
|---|---|
| Windows Terminal not installed | `where.exe wt` — nothing means no `wt.exe` to launch |
| Clicked on a non-filesystem item | "This PC", a library, or a network location has no filesystem path |
| Drive root | Right-clicking the background of a drive can produce a malformed argument — see [`internal/known-issues.md`](./internal/known-issues.md) |

There is no error dialog on any of these paths. `Invoke` returns a failure HRESULT and Explorer
discards it.

## The tab opened in the wrong window

Known. The chooser raises the window you picked and relies on `wt -w 0` — "most recently used" —
to agree. Windows may refuse the foreground change, in which case the tab lands elsewhere.

Recorded in [`internal/known-issues.md`](./internal/known-issues.md). Closing the windows you do
not want, or clicking the target window first, both work around it.

## The chooser did not appear, or appeared behind something

The chooser is a popup menu owned by a transient window in a COM surrogate, and Windows'
foreground rules apply to it too. Clicking elsewhere immediately after invoking the command can
prevent it from coming forward.

Press Escape and try again without clicking away.

## Installation fails: "the certificate is not trusted"

The install script must run **elevated** — trusting a certificate writes to LocalMachine. Check
it landed:

```powershell
Get-ChildItem Cert:\LocalMachine\Root | Where-Object Subject -like "*TerminalContextDev*"
```

## Installation fails: version already installed

Windows will not register a package whose version is not higher than the installed one. Remove
the old one first:

```powershell
Get-AppxPackage *OpenInCurrentTerminal* | Remove-AppxPackage
```

## It worked, then stopped after I moved the repository

Expected for a source install. The sparse package points at `dist\ext\` in the working copy and
Windows holds that path. Re-run `.\tools\install.ps1` from the new location.

## `run-tests.ps1` skips the integration test

By design when not elevated. Run the shell as administrator, or pass `-SkipIntegration` to be
explicit about wanting static checks only.

## `dumpbin.exe not found`

The import check locates `dumpbin` through `vswhere`. It needs Visual Studio 2022 with the C++
workload installed.

## Still stuck

[Open an issue](https://github.com/willtheorangeguy/terminal-context/issues/new/choose) with your
Windows build, the output of `Get-AppxPackage *OpenInCurrentTerminal*`, and the output of
`tests\run-tests.ps1`.
