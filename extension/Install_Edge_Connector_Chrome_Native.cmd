@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Edge Connector Chrome Native - Latest Installer

set "BASEURL=https://etech-symantec.github.io/edge-connect/extension"
set "METAURL=%BASEURL%/native-version.json"
set "TMPDIR=%TEMP%\EdgeConnectorChromeNative_%RANDOM%%RANDOM%"
set "METAFILE=%TMPDIR%\native-version.json"
set "ZIPFILE=%TMPDIR%\package.zip"

where powershell.exe >nul 2>&1 || goto :no_powershell
where tar.exe >nul 2>&1 || goto :no_tar

mkdir "%TMPDIR%" >nul 2>&1 || goto :fail

echo [1/5] Checking latest extension package...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Headers @{'Cache-Control'='no-cache, no-store'} -Uri ('%METAURL%?_=' + [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()) -OutFile '%METAFILE%'"
if errorlevel 1 goto :download_fail

for /f "usebackq delims=" %%V in (`powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "(Get-Content -Raw '%METAFILE%' | ConvertFrom-Json).version"`) do set "LATEST=%%V"
for /f "usebackq delims=" %%F in (`powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "(Get-Content -Raw '%METAFILE%' | ConvertFrom-Json).package"`) do set "PACKAGE=%%F"
for /f "usebackq delims=" %%H in (`powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "(Get-Content -Raw '%METAFILE%' | ConvertFrom-Json).sha256"`) do set "EXPECTED=%%H"
for /f "usebackq delims=" %%I in (`powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "(Get-Content -Raw '%METAFILE%' | ConvertFrom-Json).installer"`) do set "INSTALLER=%%I"

if not defined LATEST goto :meta_fail
if not defined PACKAGE goto :meta_fail
if not defined EXPECTED goto :meta_fail
if not defined INSTALLER goto :meta_fail

echo     Latest version: %LATEST%
echo [2/5] Downloading latest package...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Headers @{'Cache-Control'='no-cache, no-store'} -Uri ('%BASEURL%/%PACKAGE%?_=' + [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()) -OutFile '%ZIPFILE%'"
if errorlevel 1 goto :download_fail

echo [3/5] Verifying SHA-256...
set "ACTUAL="
for /f "usebackq delims=" %%H in (`powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "(Get-FileHash -Algorithm SHA256 -LiteralPath '%ZIPFILE%').Hash.ToLowerInvariant()"`) do set "ACTUAL=%%H"
if /I not "%ACTUAL%"=="%EXPECTED%" goto :hash_fail

echo [4/5] Extracting package...
tar.exe -xf "%ZIPFILE%" -C "%TMPDIR%"
if errorlevel 1 goto :extract_fail

if not exist "%TMPDIR%\%INSTALLER%" goto :installer_missing

echo [5/5] Starting latest installer...
call "%TMPDIR%\%INSTALLER%"
set "RC=%ERRORLEVEL%"

if "%RC%"=="0" (
  echo.
  echo [OK] Edge Connector Chrome Native %LATEST% installation completed.
) else (
  echo.
  echo [ERROR] Installer returned exit code %RC%.
)

rmdir /s /q "%TMPDIR%" >nul 2>&1
exit /b %RC%

:no_powershell
echo [ERROR] PowerShell is required.
exit /b 10

:no_tar
echo [ERROR] tar.exe is required.
exit /b 11

:download_fail
echo [ERROR] Could not download the latest package from the repo.
goto :fail_cleanup

:meta_fail
echo [ERROR] native-version.json is invalid.
goto :fail_cleanup

:hash_fail
echo [ERROR] Package SHA-256 mismatch.
echo EXPECTED: %EXPECTED%
echo ACTUAL  : %ACTUAL%
goto :fail_cleanup

:extract_fail
echo [ERROR] Could not extract the downloaded package.
goto :fail_cleanup

:installer_missing
echo [ERROR] Installer "%INSTALLER%" was not found in the package.
goto :fail_cleanup

:fail
echo [ERROR] Could not prepare the temporary folder.
exit /b 1

:fail_cleanup
rmdir /s /q "%TMPDIR%" >nul 2>&1
exit /b 1
