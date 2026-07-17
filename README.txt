G502 X PROFILE CONVERTER FOR WINDOWS
====================================

No Python or other software is required. Windows 10 or Windows 11 is required.

WHAT IT DOES
Copies button, scroll-wheel and G-Shift assignments from Logitech G502 X wired
profiles to the corresponding G502 X Lightspeed profiles. It intentionally
keeps DPI, polling and other mouse-specific settings separate.

HOW TO USE IT
1. Extract the ZIP before running it.
2. Quit Logitech G Hub from the system tray.
3. In Task Manager, confirm lghub.exe and lghub_agent.exe are closed.
4. Double-click "Run G502 X Converter.cmd".
5. Select %LOCALAPPDATA%\LGHUB\settings.db.
6. Save the converted copy when prompted.
7. Keep the original settings.db as a backup.
8. Rename the converted copy to settings.db and put it in
   %LOCALAPPDATA%\LGHUB while G Hub remains closed.
9. Start G Hub and test your profiles.

SAFETY
The selected source database is read-only. The converter creates a separate
copy and runs SQLite's integrity check before reporting success.

SHARING
Share the complete ZIP, not individual files. Recipients should extract it
before double-clicking the launcher. The PowerShell source is included so the
tool's behaviour can be inspected.
