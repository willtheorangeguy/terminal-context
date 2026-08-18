# Known Issues — terminal-context

Concrete defects and gaps found while writing this repository's documentation in
August 2026. **Nothing here was changed** — each one needs a code, configuration, or
licensing decision rather than a documentation one.

Ordered by severity. See [`docs/roadmap.md`](../roadmap.md) for the narrative version,
which also covers deliberate non-goals.


**6 open:** 1 high, 3 medium, 2 low.

## 1. A drive root produces a malformed wt command line, and the comment exempts exactly the broken case

**Severity:** High  
**Where:** `src/TerminalLauncher.cpp` -> `QuotePathForWt`

**What:** The function reads `if (path.size() > 3 && path.back() == L'\\') path.pop_back();`, under a comment saying it strips a trailing backslash '(except a bare drive root) so the closing quote is not escaped by wt's parser'. A bare drive root is `C:\` -- length 3 -- so the condition skips it and the backslash is kept, yielding the argument `-d "C:\"`. A backslash immediately before a closing quote is parsed as an escaped quote, so the argument does not terminate where intended.

**Why it matters:** The parenthetical in the comment names the one input the guard needs to handle and then excludes it, which is why this reads as correct. It is reachable: the handler registers on `Directory\Background`, so right-clicking the background of an open drive window passes exactly `C:\`. The result is a `wt` invocation with a mangled tail -- no tab, no error, and no way for the user to see why, since failures are not surfaced.

**Suggested fix:** Quote by escaping instead of trimming: double a trailing backslash run before appending the closing quote, which is correct for every path including the drive root. If trimming is preferred, `C:\` still needs a case of its own -- `wt -d C:\` unquoted works, since a drive root cannot contain spaces.

## 2. The window chooser is advisory -- the tab can open in a window the user did not pick

**Severity:** Medium  
**Where:** `src/TerminalLauncher.cpp` -> `OpenFolderInTerminal`, `BringToForeground`, `LaunchWt`

**What:** `wt` can address a window by its own identifier but not by `HWND`, so the chosen window is targeted indirectly: `BringToForeground` calls `SetForegroundWindow`, then `wt -w 0` is launched, `-w 0` meaning 'most recently used'. `SetForegroundWindow` is subject to Windows' focus-stealing restrictions, and its result is not checked. The handler runs inside a COM surrogate rather than the foreground process, which is one of the conditions under which the call is refused.

**Why it matters:** The chooser presents itself as a choice. When the foreground change is denied, the tab opens in whatever window Windows Terminal last considered current -- possibly one the user explicitly did not select -- with no indication that anything went differently. A wrong window that looks like a right one is the worst outcome available here, and it is most likely in exactly the case the chooser exists for: several windows open, the target not currently focused.

**Suggested fix:** Check `SetForegroundWindow`'s return and fall back to a path that does not depend on it. Windows Terminal's `--window` accepts a name as well as `0`; assigning names and tracking them would make the selection real. Failing that, tell the user the tab may land elsewhere rather than implying it will not.

## 3. Every failure path is silent, including on items where the command cannot work

**Severity:** Medium  
**Where:** `src/ContextCommand.cpp` -> `GetState`, `Invoke`; `src/TerminalLauncher.cpp` -> `LaunchWt`

**What:** `GetState` returns `ECS_ENABLED` without inspecting the selection, so the entry is offered on anything the shell shows it for -- including items with no filesystem path, where `GetDisplayName(SIGDN_FILESYSPATH)` fails. `Invoke` returns the failing HRESULT, and Explorer does not surface it. `LaunchWt` likewise returns a failure when `wt.exe` cannot be found or started, and nothing displays it.

**Why it matters:** The user clicks a menu item and nothing at all happens -- no window, no message, no log. Windows Terminal not being installed, a virtual folder, and a launch failure are indistinguishable from each other and from the extension being broken. For a context-menu entry, whose entire contract is 'click this and a thing happens', a silent no-op is the worst-behaved outcome and the hardest to report.

**Suggested fix:** Have `GetState` return `ECS_HIDDEN` when the selection has no filesystem path, so the command is not offered where it cannot work. Surface real failures with a brief notification or a `MessageBox` from the surrogate -- the handler is already permitted to show UI, since it shows the chooser.

## 4. The README describes a TaskDialog chooser that was deliberately removed

**Severity:** Medium  
**Where:** `README.md` 'How it works', step 3, vs `src/TerminalLauncher.cpp` -> `ChooseWindow`

**What:** The README states the handler picks a window 'via a `TaskDialog` chooser if several'. The code uses `TrackPopupMenu`, with a comment recording why: 'Uses only user32 so the handler DLL has no comctl32-version dependency (TaskDialog lives only in comctl32 v6).' `tests/run-tests.ps1` describes the same change as a 'regression guard for the comctl32-v6 / VC-runtime load failures that hide the menu'.

**Why it matters:** This is not a cosmetic staleness. The DLL failing to load produces no error anywhere -- the menu entry simply does not appear -- so someone debugging that symptom is working from the hardest possible position, and the README points them back at the exact dependency that caused it. A contributor reading 'TaskDialog' has every reason to reintroduce it.

**Suggested fix:** Update step 3 to describe the popup menu, and say why: the chooser must not pull in comctl32 v6. The reason matters more than the mechanism.

## 5. A failure to create the chooser's owner window silently selects the first terminal

**Severity:** Low  
**Where:** `src/TerminalLauncher.cpp` -> `ChooseWindow`

**What:** `ChooseWindow` returns the selected index, or `-1` for 'user cancelled'. When `CreateWindowExW` fails it returns `0` instead, commented 'Fall back to the first window.' The caller cannot distinguish that from a deliberate choice of the first entry.

**Why it matters:** The user is never shown a chooser and a tab opens in an arbitrary window -- the first in `EnumWindows` order, which has no relationship to anything they can see. It looks like the chooser was skipped on purpose. The condition is rare, but the design is the same one as the issue above: an unreportable failure resolved by guessing.

**Suggested fix:** Return a distinct value and let the caller decide -- either report the failure or launch with plain `-w 0` and no window raise, which at least behaves predictably.

## 6. Only the first item of a multi-selection is opened

**Severity:** Low  
**Where:** `src/ContextCommand.cpp` -> `Invoke`

**What:** `Invoke` calls `items->GetItemAt(0)` and ignores the rest of the `IShellItemArray`. `GetState` does not disable the command for multi-selections, so the entry appears as normal when several folders are selected.

**Why it matters:** Selecting four folders and choosing 'Open in Current Terminal' opens one tab, for whichever folder the shell happened to order first, and discards the other three without comment. The menu gave no indication it would do that.

**Suggested fix:** Either open a tab per selected folder -- `wt` accepts multiple `new-tab` commands separated by `;` in one invocation -- or return `ECS_DISABLED` from `GetState` when the count exceeds one.


---

## Also, across every repository

**`.bandit` is present on disk but untracked in git.** Verified in PyWorkout, treklogger,
skyscanner-cli, booking-cli, piggy, and aibot — the config file exists locally in each but
`git ls-files` does not know about it, so none of it reached GitHub.

The August 2026 security sweep therefore looks complete locally and landed nowhere. Worth
checking across all 44 repositories it covered.
