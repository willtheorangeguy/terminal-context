#include "ContextCommand.h"
#include "Guid.h"
#include "TerminalLauncher.h"

#include <new>
#include <string>
#include <shlwapi.h>
#include <shlobj.h>

#pragma comment(lib, "shlwapi.lib")

extern long g_dllRefs;     // DLL lock count, defined in dllmain.cpp.
extern HMODULE g_module;   // this DLL's instance, defined in dllmain.cpp.

ContextCommand::ContextCommand() : m_refs(1) {
    InterlockedIncrement(&g_dllRefs);
}

// IUnknown ------------------------------------------------------------------

IFACEMETHODIMP ContextCommand::QueryInterface(REFIID riid, void** ppv) {
    if (!ppv) {
        return E_POINTER;
    }
    if (riid == IID_IUnknown || riid == IID_IExplorerCommand) {
        *ppv = static_cast<IExplorerCommand*>(this);
        AddRef();
        return S_OK;
    }
    *ppv = nullptr;
    return E_NOINTERFACE;
}

IFACEMETHODIMP_(ULONG) ContextCommand::AddRef() {
    return InterlockedIncrement(&m_refs);
}

IFACEMETHODIMP_(ULONG) ContextCommand::Release() {
    long refs = InterlockedDecrement(&m_refs);
    if (refs == 0) {
        InterlockedDecrement(&g_dllRefs);
        delete this;
    }
    return refs;
}

// IExplorerCommand ----------------------------------------------------------

IFACEMETHODIMP ContextCommand::GetTitle(IShellItemArray*, LPWSTR* name) {
    return SHStrDupW(L"Open in Current Terminal", name);
}

IFACEMETHODIMP ContextCommand::GetIcon(IShellItemArray*, LPWSTR* icon) {
    // Use the .ico shipped alongside this DLL. (wt.exe is an app-execution alias
    // with no icon resource, so it can't be referenced directly.)
    wchar_t path[MAX_PATH];
    DWORD n = GetModuleFileNameW(g_module, path, ARRAYSIZE(path));
    if (n == 0 || n >= ARRAYSIZE(path)) {
        *icon = nullptr;
        return E_NOTIMPL;
    }
    PathRemoveFileSpecW(path);
    PathAppendW(path, L"TerminalContext.ico");
    if (!PathFileExistsW(path)) {
        *icon = nullptr;
        return E_NOTIMPL;
    }
    return SHStrDupW(path, icon);
}

IFACEMETHODIMP ContextCommand::GetToolTip(IShellItemArray*, LPWSTR* tip) {
    *tip = nullptr;
    return E_NOTIMPL;
}

IFACEMETHODIMP ContextCommand::GetCanonicalName(GUID* name) {
    *name = CLSID_OpenInTerminalCommand;
    return S_OK;
}

IFACEMETHODIMP ContextCommand::GetState(IShellItemArray*, BOOL, EXPCMDSTATE* state) {
    *state = ECS_ENABLED;
    return S_OK;
}

IFACEMETHODIMP ContextCommand::GetFlags(EXPCMDFLAGS* flags) {
    *flags = ECF_DEFAULT;
    return S_OK;
}

IFACEMETHODIMP ContextCommand::EnumSubCommands(IEnumExplorerCommand** enumCmd) {
    *enumCmd = nullptr;
    return E_NOTIMPL;
}

IFACEMETHODIMP ContextCommand::Invoke(IShellItemArray* items, IBindCtx*) {
    if (!items) {
        return E_INVALIDARG;
    }

    DWORD count = 0;
    if (FAILED(items->GetCount(&count)) || count == 0) {
        return E_INVALIDARG;
    }

    // For folder background the selection holds the open folder; for a folder
    // click it holds the folder. Either way the first item is the target.
    IShellItem* item = nullptr;
    HRESULT hr = items->GetItemAt(0, &item);
    if (FAILED(hr)) {
        return hr;
    }

    PWSTR path = nullptr;
    hr = item->GetDisplayName(SIGDN_FILESYSPATH, &path);
    item->Release();
    if (FAILED(hr)) {
        return hr;
    }

    std::wstring folder = path;
    CoTaskMemFree(path);

    return OpenFolderInTerminal(folder, GetForegroundWindow());
}
