#pragma once
#include <windows.h>
#include <shobjidl_core.h>

// IExplorerCommand handler that adds "Open in Current Terminal" to the folder and
// folder-background context menus.
class ContextCommand : public IExplorerCommand {
public:
    ContextCommand();

    // IUnknown
    IFACEMETHODIMP QueryInterface(REFIID riid, void** ppv) override;
    IFACEMETHODIMP_(ULONG) AddRef() override;
    IFACEMETHODIMP_(ULONG) Release() override;

    // IExplorerCommand
    IFACEMETHODIMP GetTitle(IShellItemArray* items, LPWSTR* name) override;
    IFACEMETHODIMP GetIcon(IShellItemArray* items, LPWSTR* icon) override;
    IFACEMETHODIMP GetToolTip(IShellItemArray* items, LPWSTR* tip) override;
    IFACEMETHODIMP GetCanonicalName(GUID* name) override;
    IFACEMETHODIMP GetState(IShellItemArray* items, BOOL okToBeSlow,
                            EXPCMDSTATE* state) override;
    IFACEMETHODIMP Invoke(IShellItemArray* items, IBindCtx* ctx) override;
    IFACEMETHODIMP GetFlags(EXPCMDFLAGS* flags) override;
    IFACEMETHODIMP EnumSubCommands(IEnumExplorerCommand** enumCmd) override;

private:
    ~ContextCommand() = default;
    long m_refs;
};
