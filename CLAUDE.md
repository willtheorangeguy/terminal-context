# Open in Current Terminal

Win11 Explorer context-menu entry that opens folders as new tabs in an existing Windows Terminal window. Sparse MSIX package + in-process COM DLL (`IExplorerCommand`).

## Build

Requires: VS 2022 (MSVC + C++ workload), Windows 11 SDK, CMake 3.20+.

```powershell
cmake -S . -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release
```

Output: `build/Release/ContextHandler.dll` + `build/Release/TerminalContextStub.exe`.

CRT is statically linked (`/MT`) — no VC++ redist dependency. This is load-bearing: the DLL runs inside a COM surrogate that has no VC runtime.

## Install (dev)

Elevated PowerShell:
```powershell
.\tools\install.ps1        # builds, signs (self-signed), registers sparse MSIX
Stop-Process -Name explorer -Force
```

Binaries served from `dist/ext/` — keep that folder in place.

## Tests

```powershell
.\tests\run-tests.ps1                    # static checks (non-elevated OK)
.\tests\run-tests.ps1 -Configuration Release  # + integration tests (elevated)
```

Static tests: build artifacts exist, DLL exports COM entry points, DLL imports only stable system DLLs.
Integration tests (admin): pack + register MSIX, `CoCreateInstance` the handler CLSID.

## Release

Tag `vX.Y.Z` triggers `.github/workflows/release.yml`. Local: `./tools/pack.ps1 -Version 1.2.3.0`.

## Architecture

```
src/
  Guid.h              CLSID {F4E9E6B5-DE73-45C8-BF95-BAB0532E1E17}
  dllmain.cpp          DLL exports + ClassFactory (IClassFactory)
  ContextCommand.*     IExplorerCommand — title, icon, Invoke
  TerminalLauncher.*   EnumWindows for WT windows, popup chooser, wt.exe launch
  ContextHandler.def   COM export table
  stub.cpp             no-op exe required by AppxManifest <Application>
package/
  AppxManifest.xml     sparse MSIX manifest (COM server + context menu verbs)
tools/
  install.ps1          dev install (sparse MSIX + external content)
  uninstall.ps1        remove package + certs
  pack.ps1             self-contained MSIX for distribution
  Install-Release.ps1  end-user installer (trust cert + register)
```

Flow: Explorer loads DLL via COM → `ContextCommand::Invoke` gets folder path from `IShellItemArray` → `OpenFolderInTerminal` enumerates WT windows (`CASCADIA_HOSTING_WINDOW_CLASS`) → shows popup menu chooser if multiple → brings chosen window to foreground → `wt -w 0 new-tab -d <path>`.

## Critical constraints

- **No comctl32 v6 imports.** The DLL loads in a COM surrogate without a v6 activation context. Importing v6-only APIs (e.g. `TaskDialog`) causes silent load failure (0x800700B6) and the menu entry disappears. The chooser uses `TrackPopupMenu` (user32) instead. The test suite guards this via `dumpbin /dependents`.
- **No VC runtime imports.** Same reason — static CRT only. Guarded by tests.
- **No external dependencies.** Links only `shlwapi`. All Win32 APIs used are stable system DLLs.
- **Trailing backslash quoting.** `QuotePathForWt` strips trailing `\` (except drive roots like `C:\`) so wt's parser doesn't treat `\"` as an escaped quote.

## CI

- `ci.yml` — runs `tests/run-tests.ps1` (static + integration on GitHub's elevated runners)
- `build.yml` — cmake build + pack MSIX + validate structure
- `release.yml` — build + pack + attach artifacts to GitHub release
