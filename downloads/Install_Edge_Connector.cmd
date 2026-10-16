@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Edge Connector - Install / Repair

set "BASEURL=https://etech-symantec.github.io/trace/downloads"
set "APPDIR=%LOCALAPPDATA%\Etech\EdgeConnector"
set "LAUNCHER=%APPDIR%\Edge_Connector_Launcher.cmd"
set "EDITOR=%APPDIR%\Edge_Connector.exe"
set "ZIPTMP=%APPDIR%\Edge_Connector.zip.download"
set "ZIPFILE=%APPDIR%\Edge_Connector.zip"
set "HASHFILE=%APPDIR%\Edge_Connector.zip.sha256"
set "EXTRACTDIR=%TEMP%\EdgeConnector_%RANDOM%%RANDOM%"
set "LOGFILE=%TEMP%\Edge_Connector_install.log"

> "%LOGFILE%" echo [%date% %time%] Install started

where curl.exe >nul 2>&1
if errorlevel 1 goto :no_curl

where tar.exe >nul 2>&1
if errorlevel 1 goto :no_tar

if not exist "%APPDIR%" mkdir "%APPDIR%" >nul 2>&1
if errorlevel 1 goto :fail

rem ------------------------------------------------------------
rem Remove leftovers of the old "ProxySG Policy Trace Edge Connector" install
rem (old install folder + old URL protocol registrations).
rem ------------------------------------------------------------
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Get-Process -ErrorAction SilentlyContinue | Where-Object { try { $_.ProcessName -like 'ProxySG_Policy_Trace_Edge Connector*' } catch { $false } } | Stop-Process -Force -ErrorAction SilentlyContinue" >nul 2>&1
reg delete "HKCU\Software\Classes\proxysg-trace-v6" /f >nul 2>&1
reg delete "HKCU\Software\Classes\proxysg-trace-v5" /f >nul 2>&1
reg delete "HKCU\Software\Classes\proxysg-trace" /f >nul 2>&1
if exist "%LOCALAPPDATA%\Etech\ProxySGTrace" rmdir /s /q "%LOCALAPPDATA%\Etech\ProxySGTrace" >nul 2>&1

rem ------------------------------------------------------------
rem Create one-shot launcher.
rem ------------------------------------------------------------
> "%LAUNCHER%" echo @echo off
>>"%LAUNCHER%" echo setlocal EnableExtensions DisableDelayedExpansion
>>"%LAUNCHER%" echo set "EDITOR=%%LOCALAPPDATA%%\Etech\EdgeConnector\Edge_Connector.exe"
>>"%LAUNCHER%" echo if exist "%%EDITOR%%" ^(
>>"%LAUNCHER%" echo   start "" "%%EDITOR%%"
>>"%LAUNCHER%" echo   exit /b 0
>>"%LAUNCHER%" echo ^)
>>"%LAUNCHER%" echo exit /b 2

if not exist "%LAUNCHER%" goto :fail

rem ------------------------------------------------------------
rem Register the edge-connector:// protocol.
rem ------------------------------------------------------------
set "REGFILE=%TEMP%\edge_connector_%RANDOM%.reg"
set "COMSPEC_ESC=%ComSpec:\=\\%"
set "LAUNCHER_ESC=%LAUNCHER:\=\\%"

> "%REGFILE%" echo Windows Registry Edge Connector Version 5.00
>>"%REGFILE%" echo.
>>"%REGFILE%" echo [HKEY_CURRENT_USER\Software\Classes\edge-connector]
>>"%REGFILE%" echo @="URL:Edge Connector Launcher"
>>"%REGFILE%" echo "URL Protocol"=""
>>"%REGFILE%" echo.
>>"%REGFILE%" echo [HKEY_CURRENT_USER\Software\Classes\edge-connector\shell\open\command]
>>"%REGFILE%" echo @="\"%COMSPEC_ESC%\" /d /c \"\"%LAUNCHER_ESC%\" \"%%1\"\""
>>"%REGFILE%" echo.

reg import "%REGFILE%" >nul 2>&1
set "RC=%ERRORLEVEL%"
del /q "%REGFILE%" >nul 2>&1
if not "%RC%"=="0" goto :fail

echo [1/6] Downloading Edge Connector ZIP...
>> "%LOGFILE%" echo [%date% %time%] Downloading Edge Connector ZIP
curl.exe -fL --retry 2 --connect-timeout 15 "%BASEURL%/Edge_Connector.zip" -o "%ZIPTMP%"
if errorlevel 1 goto :download_fail

echo [2/6] Downloading ZIP SHA-256...
>> "%LOGFILE%" echo [%date% %time%] Downloading ZIP SHA-256
curl.exe -fL --retry 2 --connect-timeout 15 "%BASEURL%/Edge_Connector.zip.sha256" -o "%HASHFILE%"
if errorlevel 1 goto :hash_download_fail

for /f "tokens=1" %%H in (%HASHFILE%) do (
  set "EXPECTED=%%H"
  goto :have_expected
)

:have_expected
if not defined EXPECTED goto :hash_invalid

set "ACTUAL="
for /f "tokens=* delims= " %%H in ('certutil -hashfile "%ZIPTMP%" SHA256 ^| findstr /R /I "^[0-9A-F][0-9A-F]*$"') do set "ACTUAL=%%H"
if not defined ACTUAL goto :hash_calc_fail

if /I not "%EXPECTED%"=="%ACTUAL%" goto :hash_mismatch

echo [3/6] SHA-256 verified.
>> "%LOGFILE%" echo [%date% %time%] ZIP SHA-256 verified
move /y "%ZIPTMP%" "%ZIPFILE%" >nul
if errorlevel 1 goto :fail_cleanup

echo [4/6] Extracting Edge Connector ZIP...
>> "%LOGFILE%" echo [%date% %time%] Extracting Edge Connector ZIP
if exist "%EXTRACTDIR%" rmdir /s /q "%EXTRACTDIR%" >nul 2>&1
mkdir "%EXTRACTDIR%" >nul 2>&1
if errorlevel 1 goto :fail_cleanup

tar.exe -xf "%ZIPFILE%" -C "%EXTRACTDIR%"
if errorlevel 1 goto :fail_cleanup

set "FOUND_EDITOR="
for /r "%EXTRACTDIR%" %%F in (Edge_Connector*.exe) do (
  if not defined FOUND_EDITOR set "FOUND_EDITOR=%%F"
)
if not defined FOUND_EDITOR goto :editor_not_found

echo [5/6] Closing running Edge Connector if needed...
>> "%LOGFILE%" echo [%date% %time%] Closing running Edge Connector before update

rem Stop only Edge Connector processes.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$target=[IO.Path]::GetFullPath($env:LOCALAPPDATA+'\Etech\EdgeConnector\Edge_Connector.exe');" ^
  "Get-Process -ErrorAction SilentlyContinue | Where-Object { try { ($_.ProcessName -like 'Edge_Connector*') -or ($_.Path -and [IO.Path]::GetFullPath($_.Path) -eq $target) } catch { $false } } | Stop-Process -Force -ErrorAction SilentlyContinue" >nul 2>&1

rem Wait briefly for Windows to release the executable file handle.
for /L %%N in (1,1,10) do (
  if not exist "%EDITOR%" goto :editor_unlocked
  2>nul (>>"%EDITOR%" echo.) && (
    rem Remove the test byte immediately by restoring from a temporary copy is undesirable.
    rem We only reach this branch if append succeeded; use copy stage directly after short delay.
    goto :editor_unlocked
  )
  ping 127.0.0.1 -n 2 >nul
)

:editor_unlocked
echo [6/6] Installing Edge Connector...
>> "%LOGFILE%" echo [%date% %time%] Installing Edge Connector

rem Copy to a temporary file first, then atomically replace the target.
copy /y "%FOUND_EDITOR%" "%APPDIR%\Edge_Connector.exe.new" >nul
if errorlevel 1 goto :copy_stage_fail

rem Ensure old target is removed after process termination.
if exist "%EDITOR%" (
  del /f /q "%EDITOR%" >nul 2>&1
)

move /y "%APPDIR%\Edge_Connector.exe.new" "%EDITOR%" >nul 2>&1
if errorlevel 1 goto :replace_fail

if exist "%EXTRACTDIR%" rmdir /s /q "%EXTRACTDIR%" >nul 2>&1

>> "%LOGFILE%" echo [%date% %time%] Installation completed successfully
echo [OK] Installation completed successfully.

rem Open callback page so the web UI changes from Install to Run.
start "" "https://etech-symantec.github.io/trace/?mode=direct&launcher=installed"

timeout /t 2 /nobreak >nul
exit /b 0

:no_curl
>> "%LOGFILE%" echo [%date% %time%] ERROR curl.exe not found
echo [ERROR] curl.exe not found.
exit /b 10

:no_tar
>> "%LOGFILE%" echo [%date% %time%] ERROR tar.exe not found
echo [ERROR] tar.exe not found.
exit /b 11

:download_fail
>> "%LOGFILE%" echo [%date% %time%] ERROR Edge Connector ZIP download failed
echo [ERROR] Edge Connector ZIP download failed.
goto :fail_cleanup

:hash_download_fail
>> "%LOGFILE%" echo [%date% %time%] ERROR SHA-256 download failed
echo [ERROR] ZIP SHA-256 download failed.
goto :fail_cleanup

:hash_invalid
>> "%LOGFILE%" echo [%date% %time%] ERROR SHA-256 file invalid
echo [ERROR] ZIP SHA-256 file is invalid.
goto :fail_cleanup

:hash_calc_fail
>> "%LOGFILE%" echo [%date% %time%] ERROR SHA-256 calculation failed
echo [ERROR] ZIP SHA-256 calculation failed.
goto :fail_cleanup

:hash_mismatch
>> "%LOGFILE%" echo [%date% %time%] ERROR SHA-256 mismatch
echo [ERROR] ZIP SHA-256 mismatch.
goto :fail_cleanup

:editor_not_found
>> "%LOGFILE%" echo [%date% %time%] ERROR Edge Connector EXE not found in ZIP
echo [ERROR] Edge Connector EXE was not found inside the ZIP.
goto :fail_cleanup

:copy_stage_fail
>> "%LOGFILE%" echo [%date% %time%] ERROR staging copy failed
echo [ERROR] Could not stage the new Edge Connector file.
goto :fail_cleanup

:replace_fail
>> "%LOGFILE%" echo [%date% %time%] ERROR target replace failed; file may still be locked
echo [ERROR] Could not replace the installed Edge Connector.
echo [ERROR] The old Edge Connector may still be running or locked by another process.
goto :fail_cleanup

:fail_cleanup
if exist "%ZIPTMP%" del /q "%ZIPTMP%" >nul 2>&1
if exist "%APPDIR%\Edge_Connector.exe.new" del /q "%APPDIR%\Edge_Connector.exe.new" >nul 2>&1
if exist "%EXTRACTDIR%" rmdir /s /q "%EXTRACTDIR%" >nul 2>&1
exit /b 1

:fail
>> "%LOGFILE%" echo [%date% %time%] ERROR launcher installation failed
echo [ERROR] Launcher installation failed.
exit /b 1
