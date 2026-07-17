@echo off
setlocal
title G502 X Profile Converter
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0G502X-Profile-Converter.ps1"
if errorlevel 1 (
  echo.
  echo The converter did not complete. See the message above for details.
  pause
)
