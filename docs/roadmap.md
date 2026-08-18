# Open in Current Terminal — Roadmap

Direction, not a schedule. Defects are tracked in
[`internal/known-issues.md`](./internal/known-issues.md); this page is about what the handler is
*for*.

## Where it is

It registers a top-level Windows 11 menu entry on folders and folder backgrounds, finds open
Windows Terminal windows, offers a chooser when there are several, and opens a tab in the one you
pick. It ships as a signed MSIX with a release workflow and an import-regression test.

## Considered

**A real code-signing certificate.** The single change that would most improve installing this.
It removes the trusted-root step entirely, which is currently the most reasonable thing for a
user to hesitate over.

**Reporting failures.** Every failure path is silent: no `wt.exe`, a non-filesystem selection, a
launch that did not start. A brief notification would turn "it does nothing" into something
actionable.

**Hiding the entry where it cannot work.** `GetState` returns `ECS_ENABLED` unconditionally, so
the command is offered on items that have no filesystem path.

**Targeting a window reliably.** The chooser is advisory, because `wt` addresses windows by its
own identifier rather than by `HWND`. Windows Terminal's `--window` accepts a name; assigning and
tracking names could make the selection real.

**Handling multi-selection.** Only the first folder in a selection is opened. Several tabs, or a
disabled entry, would both be more honest than silently ignoring the rest.

**Correcting the README's chooser description**, which still describes the `TaskDialog` that was
deliberately removed.

## Non-goals

**Opening in the current tab.** Windows Terminal provides no API for it. This is a platform
limit, not a missing feature, and no amount of work here changes it.

**Supporting Windows 10.** The top-level menu this registers into does not exist there.

**Other terminals.** Enumerating windows, choosing one, and injecting a tab is specific to
Windows Terminal's model. A generic version would be a different project.

**A settings UI.** There is nothing to configure that would not be better as a sensible default.
Adding settings means adding state, storage, and a place to put it.

**Store distribution.** The package needs `runFullTrust` and `unvirtualizedResources`, and
sideloading is the honest fit for a shell extension of this size.

## Contributing

Issues and pull requests welcome — see the
[Contributing Guide](https://github.com/willtheorangeguy/.github/blob/main/CONTRIBUTING.md).
Anything touching `src/` should keep the import list clean; `tests/run-tests.ps1` will tell you
if it does not.
