using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;

[assembly: AssemblyTitle("Scratchpad")]
[assembly: AssemblyProduct("Scratchpad")]
[assembly: AssemblyDescription("Scratchpad")]
[assembly: AssemblyCompany("Scratchpad")]
[assembly: AssemblyVersion("1.0.0.0")]

static class Launcher
{
    [STAThread]
    static void Main(string[] a)
    {
        string dir = AppDomain.CurrentDomain.BaseDirectory;
        string ps1 = Path.Combine(dir, "run.ps1");
        string args = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + ps1 + "\"";
        if (a.Length > 0 && a[0].Length > 0)
            args += " -FilePath \"" + a[0].Replace("\"", "") + "\"";

        ProcessStartInfo psi = new ProcessStartInfo("powershell.exe", args);
        psi.UseShellExecute = false;
        psi.CreateNoWindow = true;
        psi.WindowStyle = ProcessWindowStyle.Hidden;
        psi.WorkingDirectory = dir;
        Process.Start(psi);
    }
}
