#include <windows.h>
#include <shobjidl_core.h>
#include <new>

#include "Guid.h"
#include "ContextCommand.h"

// Outstanding object/lock count; the DLL may unload only when this reaches zero.
long g_dllRefs = 0;
HMODULE g_module = nullptr;  // this DLL's instance; used to locate the icon.

// Class factory ------------------------------------------------------------

class ClassFactory : public IClassFactory {
public:
    ClassFactory() : m_refs(1) { InterlockedIncrement(&g_dllRefs); }

    IFACEMETHODIMP QueryInterface(REFIID riid, void** ppv) override {
        if (!ppv) {
            return E_POINTER;
        }
        if (riid == IID_IUnknown || riid == IID_IClassFactory) {
            *ppv = static_cast<IClassFactory*>(this);
            AddRef();
            return S_OK;
        }
        *ppv = nullptr;
        return E_NOINTERFACE;
    }

    IFACEMETHODIMP_(ULONG) AddRef() override { return InterlockedIncrement(&m_refs); }

    IFACEMETHODIMP_(ULONG) Release() override {
        long refs = InterlockedDecrement(&m_refs);
        if (refs == 0) {
            InterlockedDecrement(&g_dllRefs);
            delete this;
        }
        return refs;
    }

    IFACEMETHODIMP CreateInstance(IUnknown* outer, REFIID riid, void** ppv) override {
        if (outer) {
            return CLASS_E_NOAGGREGATION;
        }
        ContextCommand* cmd = new (std::nothrow) ContextCommand();
        if (!cmd) {
            return E_OUTOFMEMORY;
        }
        HRESULT hr = cmd->QueryInterface(riid, ppv);
        cmd->Release();
        return hr;
    }

    IFACEMETHODIMP LockServer(BOOL lock) override {
        if (lock) {
            InterlockedIncrement(&g_dllRefs);
        } else {
            InterlockedDecrement(&g_dllRefs);
        }
        return S_OK;
    }

private:
    ~ClassFactory() = default;
    long m_refs;
};

// DLL exports --------------------------------------------------------------

STDAPI DllGetClassObject(REFCLSID clsid, REFIID riid, void** ppv) {
    if (clsid != CLSID_OpenInTerminalCommand) {
        return CLASS_E_CLASSNOTAVAILABLE;
    }
    ClassFactory* factory = new (std::nothrow) ClassFactory();
    if (!factory) {
        return E_OUTOFMEMORY;
    }
    HRESULT hr = factory->QueryInterface(riid, ppv);
    factory->Release();
    return hr;
}

STDAPI DllCanUnloadNow() {
    return (g_dllRefs == 0) ? S_OK : S_FALSE;
}

BOOL WINAPI DllMain(HINSTANCE module, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) {
        g_module = module;
        DisableThreadLibraryCalls(module);
    }
    return TRUE;
}
