// Starts YetiX-LED-Tool.ps1 (next to this exe) in a hidden PowerShell window.
using System;
using System.Diagnostics;
using System.IO;

[assembly: System.Reflection.AssemblyTitle("Yeti X LED Studio")]
[assembly: System.Reflection.AssemblyProduct("Yeti X LED Studio")]

static class Launcher {
  [STAThread]
  static void Main() {
    string dir = AppDomain.CurrentDomain.BaseDirectory;
    string script = Path.Combine(dir, "YetiX-LED-Tool.ps1");
    var psi = new ProcessStartInfo {
      FileName = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), @"WindowsPowerShell\v1.0\powershell.exe"),
      Arguments = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File \"" + script + "\"",
      WorkingDirectory = dir,
      UseShellExecute = false,
      CreateNoWindow = true
    };
    Process.Start(psi);
  }
}
