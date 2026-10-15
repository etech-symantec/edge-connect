@echo off
setlocal
title Prepare Edge Connector ZIP
if "%~1"=="" (
  echo Drag the old ProxySG_Policy_Trace_Editor.zip onto this CMD file.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Prepare_Edge_Connector_Zip.ps1" -ZipPath "%~1"
exit /b %ERRORLEVEL%
