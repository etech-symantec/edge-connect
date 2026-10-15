@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Edge Connector - Uninstall
set "APPDIR=%LOCALAPPDATA%\Etech\EdgeConnector"
set "LOGFILE=%TEMP%\Edge_Connector_uninstall.log"
> "%LOGFILE%" echo [%date% %time%] Uninstall started

echo [1/4] Closing Edge Connector...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Get-Process -ErrorAction SilentlyContinue|Where-Object{$_.ProcessName -like 'Edge_Connector*' -or $_.ProcessName -like 'ProxySG_Policy_Trace_Editor*'}|Stop-Process -Force -ErrorAction SilentlyContinue" >nul 2>&1
timeout /t 1 /nobreak >nul

echo [2/4] Removing URL Protocol...
reg delete "HKCU\Software\Classes\edge-connector" /f >nul 2>&1
reg delete "HKCU\Software\Classes\proxysg-trace-v6" /f >nul 2>&1
reg delete "HKCU\Software\Classes\proxysg-trace" /f >nul 2>&1

echo [3/4] Removing local files...
for /L %%N in (1,1,12) do (
  if exist "%APPDIR%" rmdir /s /q "%APPDIR%" >nul 2>&1
  if not exist "%APPDIR%" goto :removed
  timeout /t 1 /nobreak >nul
)
>>"%LOGFILE%" echo [%date% %time%] ERROR Could not remove application directory
echo [ERROR] Some files could not be removed.
echo [INFO] %LOGFILE%
exit /b 1

:removed
echo [4/4] Finishing...
start "" "https://etech-symantec.github.io/edge-connect/?connector=uninstalled&_=%RANDOM%%RANDOM%"
timeout /t 2 /nobreak >nul
exit /b 0
