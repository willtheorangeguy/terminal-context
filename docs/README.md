# Open in Current Terminal — Documentation

A Windows 11 File Explorer context-menu entry that opens the right-clicked folder as a new tab
in a Windows Terminal window you already have open.

```
terminal-context/
├── src/                  C++ COM handler, no external dependencies
│   ├── Guid.h            the CLSID
│   ├── dllmain.cpp       DLL exports and class factory
│   ├── ContextCommand.*  IExplorerCommand implementation
│   ├── TerminalLauncher.*window enumeration, chooser, wt launch
│   ├── ContextHandler.def export list
│   └── stub.cpp          placeholder exe the package requires
├── package/              sparse MSIX manifest and icon assets
├── tools/                install, uninstall, pack, install-from-release
├── tests/run-tests.ps1   static and integration checks
└── CMakeLists.txt
```

## Pages

- [Quickstart](./quickstart.md) — install from a release and use it
- [Installation](./installation.md) — from a release or from source, and why MSIX
- [Configuration](./configuration.md) — CLSID, manifest, external location, certificate
- [Architecture](./architecture.md) — from right-click to new tab
- [Development](./development.md) — building, the tests, and the import discipline
- [Deployment](./deployment.md) — packing and releasing
- [FAQ](./faq.md) — why a new tab, why a certificate, why not an MSI
- [Troubleshooting](./troubleshooting.md) — when the entry does not appear
- [Roadmap](./roadmap.md) — direction and non-goals
- [Known issues](./internal/known-issues.md) — recorded defects

## The two constraints that shape everything

**A top-level Windows 11 menu entry requires a packaged `IExplorerCommand` COM handler.**
Package identity is what grants the registration, and only MSIX confers it — a classic MSI or
EXE installer cannot. That is why a fifty-kilobyte DLL ships as a signed, sideloaded package.

**Windows Terminal has no API to run a command in an existing tab.** There is no way to `cd`
the tab you are looking at. `wt -w 0 new-tab -d "<folder>"` opens a new tab in the
most-recently-used window, and that is the closest the platform gets.

Everything else here follows from those two facts.

## Import discipline

The handler is registered as a `SurrogateServer`, so the DLL is loaded by `dllhost.exe` on
Explorer's behalf. A missing or wrong-version dependency does not produce an error — **the menu
entry simply does not appear**, with no diagnostic anywhere.

The code therefore imports only stable system DLLs, and the chooser was moved from `TaskDialog`
to `TrackPopupMenu` to shed the comctl32-v6 dependency. `tests/run-tests.ps1` guards this as a
regression check. See [Development](./development.md).
