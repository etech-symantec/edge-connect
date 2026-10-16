@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Edge Connector - Uninstall

set "APPDIR=%LOCALAPPDATA%\Etech\EdgeConnector"
set "LOGFILE=%TEMP%\Edge_Connector_uninstall.log"

> "%LOGFILE%" echo [%date% %time%] Uninstall started

echo [1/4] Closing Edge Connector...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "Get-Process -ErrorAction SilentlyContinue | Where-Object { try { ($_.ProcessName -like 'Edge_Connector*') -or ($_.Path -and $_.Path -like '*\Etech\EdgeConnector\Edge_Connector.exe') } catch { $false } } | Stop-Process -Force -ErrorAction SilentlyContinue" >nul 2>&1

timeout /t 1 /nobreak >nul

echo [2/4] Removing URL Protocol registrations...
reg delete "HKCU\Software\Classes\edge-connector" /f >nul 2>&1
rem legacy (ProxySG Policy Trace Editor) registrations
reg delete "HKCU\Software\Classes\proxysg-trace-v6" /f >nul 2>&1
reg delete "HKCU\Software\Classes\proxysg-trace-v5" /f >nul 2>&1
reg delete "HKCU\Software\Classes\proxysg-trace" /f >nul 2>&1

echo [3/4] Removing local application files...
if exist "%APPDIR%" rmdir /s /q "%APPDIR%" >nul 2>&1
if exist "%LOCALAPPDATA%\Etech\ProxySGTrace" rmdir /s /q "%LOCALAPPDATA%\Etech\ProxySGTrace" >nul 2>&1

if exist "%APPDIR%" (
  >> "%LOGFILE%" echo [%date% %time%] ERROR Could not remove application directory
  echo [ERROR] Some local files could not be removed.
  echo [ERROR] See: %LOGFILE%
  exit /b 1
)

echo [4/4] Finishing...
>> "%LOGFILE%" echo [%date% %time%] Uninstall completed successfully

start "" "https://etech-symantec.github.io/edge-connect/?mode=direct&launcher=uninstalled"

timeout /t 2 /nobreak >nul
exit /b 0
