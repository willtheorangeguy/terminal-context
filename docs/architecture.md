# Open in Current Terminal — Architecture

One DLL, four source files, no external dependencies.

```text
right-click a folder
   └── Explorer asks the registered IExplorerCommand for title, icon, state
          └── click → ContextCommand::Invoke
                 ├── read the filesystem path from the shell selection
                 └── OpenFolderInTerminal(path)
                        ├── enumerate Windows Terminal windows
                        ├── 0 → wt new-tab -d "<folder>"          (new window)
                        ├── 1 → raise it, wt -w 0 new-tab -d ...
                        └── n → popup chooser, raise, wt -w 0 ...
```

## `ContextCommand` — the shell side

Implements `IExplorerCommand`. Explorer calls it to build the menu:

| Method | Returns |
|---|---|
| `GetTitle` | "Open in Current Terminal" |
| `GetIcon` | `TerminalContext.ico` beside the DLL, or `E_NOTIMPL` |
| `GetState` | `ECS_ENABLED`, unconditionally |
| `GetFlags` | `ECF_DEFAULT` |
| `GetToolTip` / `EnumSubCommands` | `E_NOTIMPL` |
| `Invoke` | Does the work |

`Invoke` takes the **first** item from the `IShellItemArray` and asks for its
`SIGDN_FILESYSPATH`. For a folder click that is the folder; for a folder background it is the
open folder.

`GetState` returning `ECS_ENABLED` without inspecting the selection means the entry also appears
where it cannot work — see [`internal/known-issues.md`](./internal/known-issues.md).

## `TerminalLauncher` — the terminal side

**Enumerating.** `EnumWindows`, keeping visible windows whose class is
`CASCADIA_HOSTING_WINDOW_CLASS` *and* whose owning process image is `WindowsTerminal.exe`. Both
checks matter: the class name alone is not a guarantee, and `QueryFullProcessImageNameW` under
`PROCESS_QUERY_LIMITED_INFORMATION` is the cheap way to confirm.

**Choosing.** A `TrackPopupMenu` at the cursor, owned by a transient `WS_POPUP` window created
for the purpose. `TrackPopupMenu` needs a real owner to dismiss correctly on click-away, and the
`PostMessage(WM_NULL)` afterwards is the documented workaround for a long-standing dismissal
quirk.

This used to be a `TaskDialog`. It was replaced because `TaskDialog` lives only in comctl32 v6,
and that dependency made the DLL fail to load — which hides the menu entry with no error at all.
The current implementation uses nothing but user32. **The README still describes the
`TaskDialog` version**; see [`internal/known-issues.md`](./internal/known-issues.md).

**Launching.**

```text
wt.exe -w 0 new-tab -d "<folder>"
```

`wt.exe` is resolved from `%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe` first, falling back to a
bare `wt.exe` for PATH lookup. `CreateProcessW` runs it; if that fails, `ShellExecuteW` retries
so the app-execution alias can be resolved by the shell.

## Why `-w 0` and not a window handle

Windows Terminal's command line can target a window by *its own* identifier, not by `HWND`.
`-w 0` means "the most recently used window".

So the chooser cannot select a window directly. It works by calling `SetForegroundWindow` on the
window you picked and then trusting that `wt -w 0` will agree. `SetForegroundWindow` is subject
to focus-stealing restrictions, and the handler runs in a COM surrogate rather than the
foreground process — so the selection is **advisory**. See
[`internal/known-issues.md`](./internal/known-issues.md).

## Why a new tab, never the current one

Windows Terminal exposes no API to run a command in an existing tab. There is no way to `cd` the
tab you are looking at. `new-tab -d` in the existing window is the official path and the closest
the platform allows.

## Path quoting

`QuotePathForWt` strips a trailing backslash before quoting, because a backslash immediately
before a closing quote is parsed as an escape rather than a path separator. It exempts short
paths — which is exactly the case that needs it. See
[`internal/known-issues.md`](./internal/known-issues.md).

## The DLL itself

`dllmain.cpp` provides the class factory and the four standard exports
(`DllGetClassObject`, `DllCanUnloadNow`, `DllRegisterServer`, `DllUnregisterServer`), listed in
`ContextHandler.def`. Lifetime is a `g_dllRefs` count incremented per object.

`stub.cpp` builds `TerminalContextStub.exe`, which exists only because the MSIX format requires
an executable entry point. It is never run and is hidden with `AppListEntry="none"`.

## Packaging

Registration is via a **sparse MSIX**: the package declares identity and the COM/shell
extensions, while the binaries live at an external location
(`uap10:AllowExternalContent`). Package identity is the thing that grants a top-level Windows 11
menu entry, and only MSIX provides it.
