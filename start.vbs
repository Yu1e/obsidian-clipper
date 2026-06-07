' Запускает obsidian_clip.ps1 в фоне без окна консоли.
' Оба файла должны лежать в одной папке.
Dim dir : dir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
CreateObject("WScript.Shell").Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & dir & "\obsidian_clip.ps1""", 0, False