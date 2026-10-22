# New-YxShortcut: writes a .lnk through the Unicode IShellLinkW API.
# (WScript.Shell mangles non-ASCII paths such as user names with umlauts.)
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

[ComImport, Guid("000214F9-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IYxShellLinkW {
  void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder f, int c, IntPtr fd, uint fl);
  void GetIDList(out IntPtr ppidl);
  void SetIDList(IntPtr pidl);
  void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder n, int c);
  void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string n);
  void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder d, int c);
  void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string d);
  void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder a, int c);
  void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string a);
  void GetHotkey(out short k);
  void SetHotkey(short k);
  void GetShowCmd(out int s);
  void SetShowCmd(int s);
  void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder p, int c, out int i);
  void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string p, int i);
  void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string p, uint r);
  void Resolve(IntPtr h, uint f);
  void SetPath([MarshalAs(UnmanagedType.LPWStr)] string f);
}
[ComImport, Guid("0000010b-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IYxPersistFile {
  void GetClassID(out Guid c);
  [PreserveSig] int IsDirty();
  void Load([MarshalAs(UnmanagedType.LPWStr)] string f, uint m);
  void Save([MarshalAs(UnmanagedType.LPWStr)] string f, bool r);
  void SaveCompleted([MarshalAs(UnmanagedType.LPWStr)] string f);
  void GetCurFile([MarshalAs(UnmanagedType.LPWStr)] out string f);
}
[ComImport, Guid("00021401-0000-0000-C000-000000000046")] class YxCShellLink { }

public static class YxShortcut {
  public static void Create(string link, string target, string args, string workDir, string icon, string desc) {
    var sl = (IYxShellLinkW)new YxCShellLink();
    sl.SetPath(target);
    if (!string.IsNullOrEmpty(args)) sl.SetArguments(args);
    sl.SetWorkingDirectory(workDir);
    sl.SetIconLocation(icon, 0);
    sl.SetDescription(desc);
    ((IYxPersistFile)sl).Save(link, true);
  }
}
'@

function New-YxShortcut([string]$LinkPath, [string]$Target, [string]$Arguments, [string]$WorkingDirectory, [string]$Icon, [string]$Description) {
  if (Test-Path -LiteralPath $LinkPath) { Remove-Item -LiteralPath $LinkPath -Force }
  [YxShortcut]::Create($LinkPath, $Target, $Arguments, $WorkingDirectory, $Icon, $Description)
}
