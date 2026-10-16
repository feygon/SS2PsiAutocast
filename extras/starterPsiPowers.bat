@echo off
rem starterPsiPowers.bat: binds two psi_autocast starter keys in the Remaster's user.bnd.
rem   G  draws the psi amp and casts Projected Cryokinesis, overloading it automatically.
rem   J  draws the psi amp, casts Localized Pyrokinesis, then switches back to your previous weapon.
rem A key that already has a binding is left alone. Backs up user.bnd before changing it. Run it with the game closed.
setlocal

set "G_LINE=bind g "run psi\T1_Projected_Cryokinesis.cmd""
set "J_LINE=bind j "run psi\chains\Starter_Localized_Pyrokinesis.cmd""

rem Windows tools are called so a Unix "find" on the PATH (Git for Windows puts one there) can't take over:
rem findstr has no Unix namesake, and find.exe is called by its full path.
tasklist /fi "imagename eq SystemShock2Remastered.exe" 2>nul | findstr /i /c:"SystemShock2Remastered.exe" >nul
if not errorlevel 1 (
    echo The game is running. Quit it first: it rewrites user.bnd when it exits, which would undo these bindings.
    goto :end
)

rem Find user.bnd. Saved Games is a Windows known folder that can be moved (its Properties, OneDrive, policy),
rem so %USERPROFILE%\Saved Games isn't always right. In order: a folder given on the command line, Windows' own
rem location for shell:SavedGames, the Shell Folders registry value, %USERPROFILE%\Saved Games, then ask.
set "GAME_SUBDIR=Nightdive Studios\System Shock 2 Remastered"
set "BND_DIR="
if not "%~1"=="" if exist "%~1\user.bnd" set "BND_DIR=%~1"
if not defined BND_DIR (
    for /f "usebackq delims=" %%P in (`powershell -NoProfile -Command "(New-Object -ComObject Shell.Application).Namespace('shell:SavedGames').Self.Path" 2^>nul`) do (
        if exist "%%P\%GAME_SUBDIR%\user.bnd" set "BND_DIR=%%P\%GAME_SUBDIR%"
    )
)
if not defined BND_DIR (
    for /f "tokens=2,*" %%A in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" /v "{4C5C32FF-BB9D-43B0-B5B4-2D72E54EAAA4}" 2^>nul ^| findstr /c:"REG_"') do (
        if exist "%%B\%GAME_SUBDIR%\user.bnd" set "BND_DIR=%%B\%GAME_SUBDIR%"
    )
)
if not defined BND_DIR if exist "%USERPROFILE%\Saved Games\%GAME_SUBDIR%\user.bnd" set "BND_DIR=%USERPROFILE%\Saved Games\%GAME_SUBDIR%"
if not defined BND_DIR (
    echo Couldn't find user.bnd. It's in your Saved Games folder, under %GAME_SUBDIR%.
    echo If you've never started the game, start it once and quit, then run this again.
    set /p "BND_DIR=Or paste the folder that contains user.bnd here, then press Enter: "
)
if not defined BND_DIR goto :end
set "BND_DIR=%BND_DIR:"=%"
if not exist "%BND_DIR%\user.bnd" (
    echo There's no user.bnd in:
    echo   %BND_DIR%
    goto :end
)
set "BND=%BND_DIR%\user.bnd"
echo Using %BND%

rem For each key: ADD_x=1 if it's free. A plain binding only; g+shift and the like don't count.
set ADD_G=0
set ADD_J=0
call :check g "T1_Projected_Cryokinesis.cmd" ADD_G G_LINE
call :check j "Starter_Localized_Pyrokinesis.cmd" ADD_J J_LINE
if "%ADD_G%%ADD_J%"=="00" (
    echo Nothing to add. user.bnd is unchanged.
    goto :end
)

rem Back up to the first free user.bnd.before_starter_N, so earlier backups are never overwritten.
set N=1
:find_backup
if exist "%BND%.before_starter_%N%" (
    set /a N+=1
    goto :find_backup
)
copy /y "%BND%" "%BND%.before_starter_%N%" >nul || (
    echo Couldn't back up user.bnd. Nothing was changed.
    goto :end
)

rem Redirected input makes findstr end the last line with a newline even when the file doesn't.
type nul > "%BND%.starter_tmp"
findstr "^" < "%BND%" >> "%BND%.starter_tmp"
if "%ADD_G%"=="1" >> "%BND%.starter_tmp" echo %G_LINE%
if "%ADD_J%"=="1" >> "%BND%.starter_tmp" echo %J_LINE%
move /y "%BND%.starter_tmp" "%BND%" >nul || (
    echo Couldn't write user.bnd. It's unchanged; the backup is user.bnd.before_starter_%N%.
    goto :end
)

echo.
echo Done. Backup: user.bnd.before_starter_%N%
if "%ADD_G%"=="1" echo   G  casts Projected Cryokinesis, overloading it automatically.
if "%ADD_J%"=="1" echo   J  casts Localized Pyrokinesis, then switches back to your previous weapon.
echo The psi_autocast mod must be enabled for your save, and you need those disciplines learned.
goto :end

rem :check <key> <starter script name> <flag variable> <line variable>
:check
findstr /i /b /c:"bind %~1 " "%BND%" >nul
if errorlevel 1 (
    set "%~3=1"
    goto :eof
)
findstr /i /b /c:"bind %~1 " "%BND%" | findstr /i /c:"%~2" >nul
if not errorlevel 1 (
    echo %~1 is already set to the starter binding.
    goto :eof
)
echo %~1 already has your own binding, so it was left alone:
findstr /i /b /c:"bind %~1 " "%BND%"
echo To use the starter on another key, add this line with the game closed, changing %~1 to a free key:
call echo   %%%~4%%
goto :eof

:end
echo.
pause
