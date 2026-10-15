@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Edge Connector - Install / Repair

set "BASEURL=https://etech-symantec.github.io/edge-connect/downloads"
set "APPDIR=%LOCALAPPDATA%\Etech\EdgeConnector"
set "LAUNCHER=%APPDIR%\Edge_Connector_Launcher.cmd"
set "CONNECTOR=%APPDIR%\Edge_Connector.exe"
set "CONNECTORNEW=%APPDIR%\Edge_Connector.exe.new"
set "ZIPTMP=%APPDIR%\Edge_Connector.zip.download"
set "ZIPFILE=%APPDIR%\Edge_Connector.zip"
set "HASHFILE=%APPDIR%\Edge_Connector.zip.sha256"
set "VERSIONFILE=%APPDIR%\version.json"
set "VERSIONMARKER=%APPDIR%\edge-connector.version"
set "EXTRACTDIR=%TEMP%\EdgeConnector_%RANDOM%%RANDOM%"
set "LOGFILE=%TEMP%\Edge_Connector_install.log"

> "%LOGFILE%" echo [%date% %time%] Edge Connector install started

where curl.exe >nul 2>&1
if errorlevel 1 goto :no_curl
where tar.exe >nul 2>&1
if errorlevel 1 goto :no_tar

if not exist "%APPDIR%" mkdir "%APPDIR%" >nul 2>&1
if errorlevel 1 goto :fail

> "%LAUNCHER%" echo @echo off
>>"%LAUNCHER%" echo setlocal EnableExtensions DisableDelayedExpansion
>>"%LAUNCHER%" echo set "CONNECTOR=%%LOCALAPPDATA%%\Etech\EdgeConnector\Edge_Connector.exe"
>>"%LAUNCHER%" echo if exist "%%CONNECTOR%%" ^(
>>"%LAUNCHER%" echo   start "" "%%CONNECTOR%%"
>>"%LAUNCHER%" echo   exit /b 0
>>"%LAUNCHER%" echo ^)
>>"%LAUNCHER%" echo exit /b 2

rem Remove old Trace Editor URL handlers left from earlier builds.
reg delete "HKCU\Software\Classes\proxysg-trace-v6" /f >nul 2>&1
reg delete "HKCU\Software\Classes\proxysg-trace" /f >nul 2>&1

set "REGFILE=%TEMP%\edge_connector_%RANDOM%.reg"
set "COMSPEC_ESC=%ComSpec:\=\\%"
set "LAUNCHER_ESC=%LAUNCHER:\=\\%"
> "%REGFILE%" echo Windows Registry Editor Version 5.00
>>"%REGFILE%" echo.
>>"%REGFILE%" echo [HKEY_CURRENT_USER\Software\Classes\edge-connector]
>>"%REGFILE%" echo @="URL:Edge Connector"
>>"%REGFILE%" echo "URL Protocol"=""
>>"%REGFILE%" echo.
>>"%REGFILE%" echo [HKEY_CURRENT_USER\Software\Classes\edge-connector\shell\open\command]
>>"%REGFILE%" echo @="\"%COMSPEC_ESC%\" /d /c \"\"%LAUNCHER_ESC%\" \"%%1\"\""
reg import "%REGFILE%" >nul 2>&1
set "RC=%ERRORLEVEL%"
del /q "%REGFILE%" >nul 2>&1
if not "%RC%"=="0" goto :fail

echo [1/7] Downloading Edge Connector...
curl.exe -fsSL --retry 2 --connect-timeout 15 "%BASEURL%/Edge_Connector.zip" -o "%ZIPTMP%"
if errorlevel 1 goto :download_fail

echo [2/7] Downloading SHA-256...
curl.exe -fsSL --retry 2 --connect-timeout 15 "%BASEURL%/Edge_Connector.zip.sha256" -o "%HASHFILE%"
if errorlevel 1 goto :hash_download_fail

echo [3/7] Reading version...
set "CONNECTOR_VERSION="
curl.exe -fsSL --connect-timeout 10 "%BASEURL%/version.json?_=%RANDOM%%RANDOM%" -o "%VERSIONFILE%" >nul 2>&1
if exist "%VERSIONFILE%" powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue';$j=Get-Content -Raw -LiteralPath '%VERSIONFILE%'|ConvertFrom-Json;$v=@($j.edgeConnectorVersion,$j.version,$j.latestVersion)|Where-Object {$_}|Select-Object -First 1;if($v){$s=([string]$v)-replace '^v','';[IO.File]::WriteAllText('%VERSIONMARKER%',$s)}" >nul 2>&1
if exist "%VERSIONMARKER%" set /p CONNECTOR_VERSION=<"%VERSIONMARKER%"

echo [4/7] Verifying SHA-256...
set "EXPECTED="
for /f "usebackq tokens=1" %%H in ("%HASHFILE%") do set "EXPECTED=%%H"
if not defined EXPECTED goto :hash_invalid
set "ACTUAL="
for /f "tokens=* delims= " %%H in ('certutil -hashfile "%ZIPTMP%" SHA256 ^| findstr /R /I "^[0-9A-F][0-9A-F]*$"') do set "ACTUAL=%%H"
if not defined ACTUAL goto :hash_invalid
if /I not "%EXPECTED%"=="%ACTUAL%" goto :hash_mismatch
move /y "%ZIPTMP%" "%ZIPFILE%" >nul

echo [5/7] Extracting...
if exist "%EXTRACTDIR%" rmdir /s /q "%EXTRACTDIR%" >nul 2>&1
mkdir "%EXTRACTDIR%" >nul 2>&1
tar.exe -xf "%ZIPFILE%" -C "%EXTRACTDIR%"
if errorlevel 1 goto :fail_cleanup

set "FOUND_CONNECTOR="
for /r "%EXTRACTDIR%" %%F in (Edge_Connector*.exe) do if not defined FOUND_CONNECTOR set "FOUND_CONNECTOR=%%F"
if defined FOUND_CONNECTOR goto :found
rem Migration support for the old package filename.
for /r "%EXTRACTDIR%" %%F in (ProxySG_Policy_Trace_Editor*.exe) do if not defined FOUND_CONNECTOR set "FOUND_CONNECTOR=%%F"
:found
if not defined FOUND_CONNECTOR goto :connector_not_found

echo [6/7] Closing running Edge Connector...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Get-Process -ErrorAction SilentlyContinue|Where-Object{$_.ProcessName -like 'Edge_Connector*' -or $_.ProcessName -like 'ProxySG_Policy_Trace_Editor*'}|Stop-Process -Force -ErrorAction SilentlyContinue" >nul 2>&1
timeout /t 1 /nobreak >nul

echo [7/7] Installing Edge Connector...
if exist "%CONNECTORNEW%" del /f /q "%CONNECTORNEW%" >nul 2>&1
copy /y "%FOUND_CONNECTOR%" "%CONNECTORNEW%" >nul
if errorlevel 1 goto :fail_cleanup
if exist "%CONNECTOR%" del /f /q "%CONNECTOR%" >nul 2>&1
move /y "%CONNECTORNEW%" "%CONNECTOR%" >nul 2>&1
if errorlevel 1 goto :fail_cleanup
if exist "%EXTRACTDIR%" rmdir /s /q "%EXTRACTDIR%" >nul 2>&1

echo [OK] Edge Connector installation completed.
if defined CONNECTOR_VERSION (
  start "" "https://etech-symantec.github.io/edge-connect/?connector=installed&version=%CONNECTOR_VERSION%&_=%RANDOM%%RANDOM%"
) else (
  start "" "https://etech-symantec.github.io/edge-connect/?connector=installed&_=%RANDOM%%RANDOM%"
)
timeout /t 2 /nobreak >nul
exit /b 0

:no_curl
echo [ERROR] curl.exe not found.
exit /b 10
:no_tar
echo [ERROR] tar.exe not found.
exit /b 11
:download_fail
echo [ERROR] Edge_Connector.zip download failed.
goto :fail_cleanup
:hash_download_fail
echo [ERROR] Edge_Connector.zip.sha256 download failed.
goto :fail_cleanup
:hash_invalid
echo [ERROR] SHA-256 information is invalid.
goto :fail_cleanup
:hash_mismatch
echo [ERROR] SHA-256 mismatch.
goto :fail_cleanup
:connector_not_found
echo [ERROR] Edge Connector EXE was not found inside the ZIP.
goto :fail_cleanup
:fail_cleanup
if exist "%ZIPTMP%" del /q "%ZIPTMP%" >nul 2>&1
if exist "%CONNECTORNEW%" del /q "%CONNECTORNEW%" >nul 2>&1
if exist "%EXTRACTDIR%" rmdir /s /q "%EXTRACTDIR%" >nul 2>&1
exit /b 1
:fail
echo [ERROR] Edge Connector installation failed.
exit /b 1
