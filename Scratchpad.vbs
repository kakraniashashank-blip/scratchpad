' Launches Scratchpad with no console window.
' An optional argument is a file to open (used by the .md file association).
Dim sh, base, cmd, arg
Set sh = CreateObject("WScript.Shell")
base = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & base & "run.ps1"""
If WScript.Arguments.Count > 0 Then
  arg = WScript.Arguments(0)
  cmd = cmd & " -FilePath """ & arg & """"
End If
sh.Run cmd, 0, False
