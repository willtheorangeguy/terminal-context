#include "TerminalLauncher.h"

#include <vector>
#include <string>
#include <shlwapi.h>
#include <shlobj.h>
#include <shellapi.h>
#include <psapi.h>

#pragma comment(lib, "shlwapi.lib")

namespace {

// Windows Terminal's top-level window class.
constexpr wchar_t kWtWindowClass[] = L"CASCADIA_HOSTING_WINDOW_CLASS";

struct TerminalWindow {
    HWND hwnd;
    std::wstring title;
};

// True if the process that owns hwnd has image name "WindowsTerminal.exe".
bool IsWindowsTerminalProcess(HWND hwnd) {
    DWORD pid = 0;
    GetWindowThreadProcessId(hwnd, &pid);
    if (pid == 0) {
        return false;
    }

    HANDLE proc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (!proc) {
        return false;
    }

    wchar_t image[MAX_PATH];
    DWORD size = ARRAYSIZE(image);
    bool match = false;
    if (QueryFullProcessImageNameW(proc, 0, image, &size)) {
        PCWSTR name = PathFindFileNameW(image);
        match = (_wcsicmp(name, L"WindowsTerminal.exe") == 0);
    }
    CloseHandle(proc);
    return match;
}

BOOL CALLBACK EnumProc(HWND hwnd, LPARAM lparam) {
    if (!IsWindowVisible(hwnd)) {
        return TRUE;
    }

    wchar_t cls[64];
    if (GetClassNameW(hwnd, cls, ARRAYSIZE(cls)) == 0) {
        return TRUE;
    }
    if (_wcsicmp(cls, kWtWindowClass) != 0) {
        return TRUE;
    }
    if (!IsWindowsTerminalProcess(hwnd)) {
        return TRUE;
    }

    wchar_t title[512];
    int len = GetWindowTextW(hwnd, title, ARRAYSIZE(title));
    std::wstring text = (len > 0) ? std::wstring(title, len) : L"Windows Terminal";

    auto* list = reinterpret_cast<std::vector<TerminalWindow>*>(lparam);
    list->push_back({hwnd, std::move(text)});
    return TRUE;
}

std::vector<TerminalWindow> EnumerateTerminalWindows() {
    std::vector<TerminalWindow> windows;
    EnumWindows(EnumProc, reinterpret_cast<LPARAM>(&windows));
    return windows;
}

// Show a popup menu (at the cursor) with one entry per window. Returns the
// selected index, or -1 if cancelled. Uses only user32 so the handler DLL has no
// comctl32-version dependency (TaskDialog lives only in comctl32 v6).
int ChooseWindow(const std::vector<TerminalWindow>& windows) {
    // A transient owner window so the menu can take foreground and dismiss
    // correctly. TrackPopupMenu requires a real (non message-only) owner.
    static const wchar_t kCls[] = L"TerminalContextMenuOwner";
    WNDCLASSW wc = {};
    wc.lpfnWndProc = DefWindowProcW;
    wc.hInstance = GetModuleHandleW(nullptr);
    wc.lpszClassName = kCls;
    RegisterClassW(&wc);  // ignore ERROR_CLASS_ALREADY_EXISTS

    HWND owner = CreateWindowExW(WS_EX_TOOLWINDOW, kCls, L"", WS_POPUP,
                                 0, 0, 0, 0, nullptr, nullptr,
                                 wc.hInstance, nullptr);
    if (!owner) {
        return 0;  // Fall back to the first window.
    }

    HMENU menu = CreatePopupMenu();
    for (size_t i = 0; i < windows.size(); ++i) {
        AppendMenuW(menu, MF_STRING, i + 1, windows[i].title.c_str());
    }

    POINT pt;
    GetCursorPos(&pt);
    SetForegroundWindow(owner);  // required for the menu to dismiss on click-away
    UINT cmd = TrackPopupMenu(menu,
                              TPM_RETURNCMD | TPM_NONOTIFY | TPM_LEFTALIGN,
                              pt.x, pt.y, 0, owner, nullptr);
    PostMessageW(owner, WM_NULL, 0, 0);  // documented dismissal quirk

    DestroyMenu(menu);
    DestroyWindow(owner);

    return (cmd == 0) ? -1 : static_cast<int>(cmd) - 1;
}

// Quote a path for the wt command line, stripping a trailing backslash (except a
// bare drive root) so the closing quote is not escaped by wt's parser.
std::wstring QuotePathForWt(std::wstring path) {
    if (path.size() > 3 && path.back() == L'\\') {
        path.pop_back();
    }
    return L"\"" + path + L"\"";
}

// Resolve wt.exe. The app-execution alias lives under WindowsApps (on PATH), but
// resolve an explicit path first so CreateProcess works regardless of PATH.
std::wstring ResolveWtPath() {
    wchar_t local[MAX_PATH];
    if (SUCCEEDED(SHGetFolderPathW(nullptr, CSIDL_LOCAL_APPDATA, nullptr, 0, local))) {
        std::wstring p = std::wstring(local) +
                         L"\\Microsoft\\WindowsApps\\wt.exe";
        if (PathFileExistsW(p.c_str())) {
            return p;
        }
    }
    return L"wt.exe";  // Fall back to PATH lookup.
}

HRESULT LaunchWt(const std::wstring& args) {
    std::wstring wt = ResolveWtPath();

    // CreateProcessW needs a mutable command line buffer (argv[0] + args).
    std::wstring cmd = L"\"" + wt + L"\" " + args;
    std::vector<wchar_t> buf(cmd.begin(), cmd.end());
    buf.push_back(L'\0');

    STARTUPINFOW si = {};
    si.cb = sizeof(si);
    PROCESS_INFORMATION pi = {};

    BOOL ok = CreateProcessW(nullptr, buf.data(), nullptr, nullptr, FALSE,
                             CREATE_NO_WINDOW, nullptr, nullptr, &si, &pi);
    if (!ok) {
        // Last resort: let the shell resolve the alias.
        HINSTANCE r = ShellExecuteW(nullptr, L"open", wt.c_str(), args.c_str(),
                                    nullptr, SW_SHOWNORMAL);
        return (reinterpret_cast<INT_PTR>(r) > 32) ? S_OK
                                                   : HRESULT_FROM_WIN32(GetLastError());
    }
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    return S_OK;
}

// SetForegroundWindow has focus-stealing restrictions; restore a minimized
// window and try to bring it forward so wt -w 0 (most-recently-used) targets it.
void BringToForeground(HWND hwnd) {
    if (IsIconic(hwnd)) {
        ShowWindow(hwnd, SW_RESTORE);
    }
    SetForegroundWindow(hwnd);
    BringWindowToTop(hwnd);
}

}  // namespace

HRESULT OpenFolderInTerminal(const std::wstring& folderPath, HWND ownerHwnd) {
    if (folderPath.empty()) {
        return E_INVALIDARG;
    }
    (void)ownerHwnd;  // Chooser uses its own transient owner window.

    const std::wstring quoted = QuotePathForWt(folderPath);
    std::vector<TerminalWindow> windows = EnumerateTerminalWindows();

    if (windows.empty()) {
        // No terminal open: a plain new-tab opens a fresh window.
        return LaunchWt(L"new-tab -d " + quoted);
    }

    size_t index = 0;
    if (windows.size() > 1) {
        int chosen = ChooseWindow(windows);
        if (chosen < 0) {
            return S_FALSE;  // User cancelled.
        }
        index = static_cast<size_t>(chosen);
    }

    // Make the target window most-recently-used so `wt -w 0` lands there, and
    // raise it so the new (auto-activated) tab is visible.
    BringToForeground(windows[index].hwnd);

    return LaunchWt(L"-w 0 new-tab -d " + quoted);
}
