# Open in Current Terminal — Configuration

Nothing is configurable at runtime — no settings, no registry keys of your own, no options page.
This page documents the identifiers and paths that make the handler work, all of which are
build-time constants.

## The CLSID

`src/Guid.h` holds `CLSID_OpenInTerminalCommand`, the class ID Windows uses to instantiate the
handler.

It appears in three places that must agree:

| Where | Purpose |
|---|---|
| `src/Guid.h` | The definition |
| `package/AppxManifest.xml` | `com:Class Id` and the shell extension registration |
| `tests/run-tests.ps1` | Activation check in the integration tests |

Changing it in one place and not the others produces a package that registers cleanly and does
nothing.

## The MSIX manifest

`package/AppxManifest.xml` declares:

- **Package identity** — `TerminalContext.OpenInCurrentTerminal`, publisher
  `CN=TerminalContextDev`, and the version. The publisher string must match the certificate's
  subject exactly, or signing fails.
- **`uap10:AllowExternalContent`** — what permits the sparse, external-location install below.
- **`runFullTrust` and `unvirtualizedResources`** — restricted capabilities, which is part of
  why the package is sideloaded rather than store-distributed.
- **`com:ComServer` / `com:SurrogateServer`** — an STA class pointing at `ContextHandler.dll`.
  Being a surrogate server means the DLL is loaded by `dllhost.exe` rather than by Explorer
  itself, which is why the chooser window belongs to a surrogate process.
- **`desktop4:Extension` with `desktop5:ItemType`** — the shell registration, binding the CLSID
  to `Directory` and `Directory\Background`.
- **A placeholder application** — `TerminalContextStub.exe`, built from `src/stub.cpp`, with
  `AppListEntry="none"`. The package format requires an executable entry point; nothing ever
  runs it and it is hidden from the Start menu.

## Version

Set at pack time:

```powershell
./tools/pack.ps1 -Version 1.2.3.0
```

MSIX versions are four-part and the fourth must be `0`. Windows refuses to register a package
whose version is not higher than the installed one, so a reinstall of the same version needs the
old package removed first.

## The external location (source installs)

`install.ps1` registers a sparse package with `Add-AppxPackage -ExternalLocation`, pointing at
`dist\ext\` in the repository. Windows holds that path; the files are not copied anywhere.

Consequences worth stating:

- The repository folder must stay put.
- Rebuilding the DLL into `dist\ext\` updates the installed handler without re-registering —
  though Explorer must be restarted, since it has the old DLL loaded.
- A release install has no external location; it is self-contained.

## The certificate

Created by `install.ps1` (or on the CI runner by `pack.ps1`), self-signed, trusted into
LocalMachine. The subject must match the manifest's `Publisher` attribute.

To use a real code-signing certificate, store the PFX in repository secrets and adjust
`pack.ps1` and the release workflow. See [Deployment](./deployment.md).

## The icon

`GetIcon` resolves `TerminalContext.ico` next to the loaded DLL. If the file is missing the
method returns `E_NOTIMPL` and the entry appears without an icon rather than failing — a
deliberate choice, since a missing icon is not a reason to lose the command.

`wt.exe` cannot be referenced for its icon: it is an app-execution alias, a zero-byte reparse
point with no icon resource.

## What the handler runs

```text
wt.exe -w 0 new-tab -d "<folder>"
```

`wt.exe` is resolved from `%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe` if it exists, falling
back to a PATH lookup. `-w 0` targets the most-recently-used window; see
[Architecture](./architecture.md) for why that is not the same as the window you chose.
