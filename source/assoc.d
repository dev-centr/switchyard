module assoc;

import core.sys.windows.windef;
import core.sys.windows.winreg;
import std.array : appender;
import std.string : startsWith, toLower;
import std.utf : toUTF8, toUTF16z;

/// One file-extension association snapshot (open / icon tracks).
struct AssocSnapshot
{
    string extension; /// e.g. ".docx" (leading dot)
    string progId;
    string openCommand;
    string defaultIcon;
    string friendlyTypeName;
}

private string readRegSz(HKEY root, string subKey, string valueName)
{
    HKEY hKey;
    auto subW = subKey.toUTF16z;
    if (RegOpenKeyExW(root, subW, 0, KEY_READ, &hKey) != ERROR_SUCCESS)
        return null;
    scope (exit)
        RegCloseKey(hKey);

    DWORD typ;
    DWORD cb;
    auto nameW = valueName.length ? valueName.toUTF16z : null;
    if (RegQueryValueExW(hKey, nameW, null, &typ, null, &cb) != ERROR_SUCCESS)
        return null;
    if (typ != REG_SZ && typ != REG_EXPAND_SZ)
        return null;
    if (cb == 0)
        return "";

    auto buf = new wchar[](cb / wchar.sizeof + 1);
    if (RegQueryValueExW(hKey, nameW, null, &typ, cast(LPBYTE) buf.ptr, &cb) != ERROR_SUCCESS)
        return null;
    auto n = cb / wchar.sizeof;
    if (n && buf[n - 1] == 0)
        n--;
    return buf[0 .. n].toUTF8;
}

/// Read association tracks for `ext` (with or without leading dot).
AssocSnapshot readAssoc(string ext)
{
    if (!ext.startsWith("."))
        ext = "." ~ ext;
    ext = ext.toLower;

    AssocSnapshot s;
    s.extension = ext;
    // Classic default ProgID under HKCR\.<ext>
    s.progId = readRegSz(HKEY_CLASSES_ROOT, ext, null);
    // Windows 8+ user default often lives only under FileExts\...\UserChoice
    if (!s.progId.length)
    {
        auto uc = `Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\`
            ~ ext ~ `\UserChoice`;
        s.progId = readRegSz(HKEY_CURRENT_USER, uc, "ProgId");
    }
    s.friendlyTypeName = s.progId.length
        ? readRegSz(HKEY_CLASSES_ROOT, s.progId, null) : null;
    s.defaultIcon = readRegSz(HKEY_CLASSES_ROOT, ext ~ `\DefaultIcon`, null);
    if (!s.defaultIcon.length && s.progId.length)
        s.defaultIcon = readRegSz(HKEY_CLASSES_ROOT, s.progId ~ `\DefaultIcon`, null);
    if (s.progId.length)
        s.openCommand = readRegSz(HKEY_CLASSES_ROOT, s.progId ~ `\shell\open\command`, null);
    return s;
}

string formatSnapshot(AssocSnapshot s)
{
    auto app = appender!string;
    app.put("extension ");
    app.put(s.extension);
    app.put("\n");
    void line(string k, string v)
    {
        app.put("  ");
        app.put(k);
        app.put(" ");
        app.put(v.length ? v : "(none)");
        app.put("\n");
    }

    line("progId", s.progId);
    line("friendly", s.friendlyTypeName);
    line("defaultIcon", s.defaultIcon);
    line("open", s.openCommand);
    return app.data;
}
