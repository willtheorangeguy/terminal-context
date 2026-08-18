# Open in Current Terminal — Deployment

## Releasing

Publish a GitHub release tagged `vX.Y.Z`. `.github/workflows/release.yml` then builds x64
Release, packs a signed self-contained MSIX via `tools/pack.ps1`, and attaches:

| Artifact | For |
|---|---|
| `.msix` | The package itself |
| `.cer` | The certificate a user must trust before Windows will sideload it |
| `.zip` | Both, plus `Install-Release.ps1` |

Locally:

```powershell
./tools/pack.ps1 -Version 1.2.3.0
```

MSIX versions are four-part with a trailing `0`, and Windows refuses to register a package whose
version is not higher than the one installed — so bump it for every release you intend to
install over an existing one.

## Release packages are self-contained

Unlike a source install, a release MSIX carries its own binaries. There is no external location
and no dependency on any folder staying put.

## Signing

CI generates a **self-signed** certificate on the runner and signs with it. That means each
release is signed by a different certificate, and every user must trust the `.cer` shipped
alongside it before the package will install.

For a smoother experience, use a real code-signing certificate: store the PFX in repository
secrets and adjust `pack.ps1` and the workflow to use it. Then `Install-Release.ps1` no longer
needs to add anything to the trusted root store, which is the part of the current instructions
that most deserves a user's hesitation.

The certificate subject must match the manifest's `Publisher` (`CN=TerminalContextDev`) exactly.
Changing one means changing the other.

## What a user is being asked to do

Worth being clear about, since the install script does it on their behalf:

1. Add a certificate to **LocalMachine → Trusted Root Certification Authorities**.
2. Sideload an MSIX signed by it.

Step 1 is not a small ask — a trusted root can vouch for anything. A real code-signing
certificate removes the need for it entirely.

## Installing on another machine

Either install the same `.cer` into its LocalMachine trusted root store, or sign with a
certificate it already trusts.

## Uninstalling

```powershell
Get-AppxPackage *OpenInCurrentTerminal* | Remove-AppxPackage
Stop-Process -Name explorer -Force
```

This leaves the certificate in the trusted root store. Remove it from `certlm.msc` separately —
nothing in the tooling does.
