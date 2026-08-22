# Open in Current Terminal — FAQ

## Why does it open a new tab instead of using the one I am looking at?

Windows Terminal has no API to run a command in an existing tab. There is no supported way to
`cd` the tab in front of you — from this handler or from anything else.

`wt -w 0 new-tab -d "<folder>"` is the official path, and a new tab in the window you already
have is the closest the platform allows.

## Why does it need an MSIX package?

A top-level Windows 11 context-menu entry must come from a packaged `IExplorerCommand` COM
handler, and that registration requires package identity. Only MSIX grants it — a classic MSI or
EXE installer cannot.

The alternative is a legacy shell extension, which Windows 11 buries under "Show more options".

## Why do I have to trust a certificate?

Windows will not sideload an unsigned MSIX. The bundled certificate is self-signed, so your
machine has no reason to trust it until you say so.

It is a real ask — a trusted root can vouch for anything — and it exists only because there is no
code-signing certificate behind this project. See [Deployment](./deployment.md).

## Can I install it without touching the trusted root store?

Not as it ships. Signing with a real code-signing certificate would remove the need entirely,
and the workflow is set up so that swapping one in is a small change.

## The entry does not appear

Three usual causes: Explorer was not restarted, the package did not register, or the DLL failed
to load. The third produces **no error of any kind** — see [Troubleshooting](./troubleshooting.md).

## Why does the tab sometimes open in the wrong window?

The chooser cannot target a window directly: `wt` addresses windows by its own identifier, not
by `HWND`. Picking a window works by raising it and trusting `wt -w 0` — "most recently used" —
to agree.

Windows restricts which processes may take the foreground, and this runs in a COM surrogate. When
the raise is refused, the tab lands wherever Windows Terminal considers most recent. Recorded in
[`internal/known-issues.md`](./internal/known-issues.md).

## Does it work with PowerShell, cmd, or WSL tabs?

Yes. It opens a tab with your default profile at that directory; which shell that is comes from
your Windows Terminal settings.

## Does it work on Windows 10?

No. The manifest requires 10.0.22000 or later — Windows 11. The top-level menu it registers into
does not exist on Windows 10.

## Does it need Windows Terminal installed?

Yes. Without `wt.exe` the launch fails, silently.

## What does it do when no terminal is open?

Opens a new Windows Terminal window at that folder.

## I selected several folders and only one opened

By design, and worth knowing: `Invoke` takes the first item in the selection. Recorded in
[`internal/known-issues.md`](./internal/known-issues.md).

## Does it send anything anywhere?

No. It reads a path from the shell, enumerates windows, and starts a process. There is no
network code in this project.

## Can I move the repository after installing from source?

No. A source install serves its binaries from `dist\ext\` in the working copy, and Windows holds
that path. Move it and re-run `install.ps1`. Release installs are self-contained.
