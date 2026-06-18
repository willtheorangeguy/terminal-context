#pragma once
#include <windows.h>
#include <string>

// Enumerate open Windows Terminal windows, let the user pick one when there is
// more than one, and open the given folder as a new tab in it (creating a new
// window only when none is open). Brings the chosen window to the foreground so
// the freshly-activated tab is visible.
//
// folderPath: filesystem path to open. ownerHwnd: parent for the chooser dialog
// (may be NULL). Returns S_OK on a launch attempt, or an HRESULT error.
HRESULT OpenFolderInTerminal(const std::wstring& folderPath, HWND ownerHwnd);
