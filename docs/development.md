# Open in Current Terminal — Development

## Requirements

Visual Studio 2022 with the MSVC C++ workload, the Windows 11 SDK, and CMake. No package
manager, no vcpkg, no external libraries — the handler links only against system import
libraries.

## Build

```powershell
cmake -S . -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release
```

Output lands in `build\Release\`: `ContextHandler.dll` and `TerminalContextStub.exe`.

## Install and iterate

```powershell
# elevated, once
.\tools\install.ps1
Stop-Process -Name explorer -Force
```

After that, rebuilding into `dist\ext\` updates the installed handler in place — the sparse
package points at that folder rather than holding a copy. Restart Explorer to pick up the new
DLL, since the old one is still loaded.

## Tests

```powershell
.\tests\run-tests.ps1                    # static checks
.\tests\run-tests.ps1                    # elevated: also packs, registers, activates
.\tests\run-tests.ps1 -SkipIntegration   # static only, even when elevated
```

The script builds first if `build\Release\ContextHandler.dll` is missing, and exits non-zero if
any case fails.

**Static checks**

| Check | Guards against |
|---|---|
| Build artifacts exist | An incomplete build |
| COM exports present | A broken `.def` file |
| Imports only stable system DLLs | The failure mode below |

**Integration check** (elevated) packs the MSIX, registers it, and `CoCreateInstance`s the CLSID
— proving the DLL really loads and the class factory works, rather than merely that it compiled.

## The import discipline, and why it has a test

The DLL is loaded by a COM surrogate on Explorer's behalf. When a dependency is missing or the
wrong version, **nothing reports an error** — the menu entry simply does not appear. There is no
dialog, no event log entry, and no way to tell it apart from a registration problem.

Two things have caused this: a comctl32 v6 dependency (from `TaskDialog`) and the VC runtime.
Hence:

- The chooser uses `TrackPopupMenu` from user32 rather than `TaskDialog`.
- The import list is asserted by a test.

**Before adding any API, check which DLL it comes from.** A convenient helper from a
non-guaranteed library costs the whole feature, silently.

## Conventions

- **No external dependencies.** Not a stylistic preference — see above.
- **Static-link or avoid the CRT** where the build permits it.
- **`ContextHandler.def` lists the exports.** A new export must be added there or it will not
  be visible.
- **The CLSID lives in three files** — `src/Guid.h`, `package/AppxManifest.xml`, and
  `tests/run-tests.ps1`. Change all three together.

## CI

| Workflow | Does |
|---|---|
| `ci.yml` | Runs `tests/run-tests.ps1` on push and PR |
| `build.yml` | Compiles and validates the MSIX |
| `release.yml` | On a published `vX.Y.Z` release: builds x64 Release, packs a signed MSIX, attaches artifacts |

CI runners are not elevated, so the integration test is skipped there. The static checks — which
include the import guard — do run.

## Recording defects

Bugs found while working here go in [`internal/known-issues.md`](./internal/known-issues.md)
rather than being fixed in passing, unless fixing them is the job you are on.
