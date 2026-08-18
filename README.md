<!-- Logo -->
<h1 align="center">Open in Current Terminal</h1>

<!-- Copy -->
<h4 align="center">A Windows 11 context-menu entry that opens the right-clicked folder as a tab in the Windows Terminal window you already have open.</h4>

<!-- Badges -->
<div align="center">
  <img alt="CI" src="https://img.shields.io/github/actions/workflow/status/willtheorangeguy/terminal-context/ci.yml?label=ci">
  <img alt="GitHub Issues" src="https://img.shields.io/github/issues/willtheorangeguy/terminal-context">
  <img alt="GitHub Pull Requests" src="https://img.shields.io/github/issues-pr/willtheorangeguy/terminal-context">
  <img alt="License" src="https://img.shields.io/github/license/willtheorangeguy/terminal-context">
</div>

<!-- Navigation -->
<p align="center">
  <a href="#key-features">Key Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#documentation">Documentation</a> •
  <a href="#support">Support</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#credits">Credits</a> •
  <a href="#license">License</a>
</p>

## Key Features

- Appears in the **main** Windows 11 right-click menu, not buried under "Show more options".
- Works on folders and on folder backgrounds.
- Opens a tab in an existing Windows Terminal window instead of spawning a new one.
- Shows a chooser when several terminal windows are open, and raises the one you pick.
- A single in-process COM DLL with no external dependencies — it imports only stable system DLLs.

## Installation

Download the latest `OpenInCurrentTerminal_*.zip` from [Releases](https://github.com/willtheorangeguy/terminal-context/releases), extract it, then from an **elevated** PowerShell:

```powershell
.\Install-Release.ps1
Stop-Process -Name explorer -Force
```

Building from source, and why it needs an MSIX at all, are in [`docs/installation.md`](docs/installation.md).

## Usage

Right-click a folder, or the background of an open folder, and choose **Open in Current Terminal**.

## Documentation

Full documentation lives in [`docs/`](docs/README.md):
[Quickstart](docs/quickstart.md) · [Installation](docs/installation.md) · [Configuration](docs/configuration.md) · [Architecture](docs/architecture.md) · [Development](docs/development.md) · [Deployment](docs/deployment.md) · [FAQ](docs/faq.md) · [Troubleshooting](docs/troubleshooting.md) · [Roadmap](docs/roadmap.md)

## Support

Open a [GitHub Discussion](https://github.com/willtheorangeguy/terminal-context/discussions/new) or file an [issue](https://github.com/willtheorangeguy/terminal-context/issues/new/choose).

## Contributing

Contributions welcome. See the org-wide [Contributing Guide](https://github.com/willtheorangeguy/.github/blob/main/CONTRIBUTING.md) and [Code of Conduct](https://github.com/willtheorangeguy/.github/blob/main/CODE_OF_CONDUCT.md).

## Credits

Built on the Windows Shell's [`IExplorerCommand`](https://learn.microsoft.com/windows/win32/api/shobjidl_core/nn-shobjidl_core-iexplorercommand) interface and [Windows Terminal](https://github.com/microsoft/terminal)'s `wt` command line. Not affiliated with Microsoft.

## License

MIT — see [`LICENSE.md`](LICENSE.md).

> Windows Terminal has no API to run a command in an existing tab, so this opens a new tab in the existing window. That is the closest thing the platform allows.
