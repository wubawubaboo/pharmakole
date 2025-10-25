@echo off

REM 1. Paths (SET values without quotes)
SET XAMPP_MYSQL_PATH=C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqldump.exe
SET GDRIVE_PATH=G:\My Drive\DB_Backup
SET LOCAL_PATH=C:\Users\ludwi\OneDrive\Documents\DB_LocalBackups

REM 2. Database credentials
SET DB_USER=root
SET DB_PASS=imsherlocked26@
SET DB_NAME=pharma_db

REM SCRIPT LOGIC

echo Generating timestamp...
FOR /f "delims=" %%a IN ('powershell -c "Get-Date -Format 'yyyy-MM-dd_HH-mm'"') DO SET DATETIME=%%a

IF "%DATETIME%"=="" (
    echo.
    echo !! ERROR: Failed to generate timestamp. !!
    echo Please ensure PowerShell is working correctly.
    echo.
    PAUSE
    GOTO :EOF
)

echo Timestamp: %DATETIME%
SET FILENAME=%DB_NAME%_backup_%DATETIME%.sql

REM EXECUTION

echo --- Starting Google Drive Backup ---
CALL :MAKE_BACKUP "%GDRIVE_PATH%"
echo.

echo --- Starting Local OneDrive Backup ---
CALL :MAKE_BACKUP "%LOCAL_PATH%"
echo.

echo All backup tasks complete.
PAUSE
GOTO :EOF

REM
REM SUBROUTINE: MAKE_BACKUP
:MAKE_BACKUP
SET TARGET_DIR=%~1
SET FULL_PATH="%TARGET_DIR%\%FILENAME%"
SET LOG_PATH="%TARGET_DIR%\%FILENAME%.log"

echo Backing up %DB_NAME% to %FULL_PATH%...

"%XAMPP_MYSQL_PATH%" -h 127.0.0.1 -u %DB_USER% -p"%DB_PASS%" %DB_NAME% > %FULL_PATH% 2> %LOG_PATH%

IF %ERRORLEVEL% NEQ 0 (
    echo.
    echo !! BACKUP FAILED FOR: %TARGET_DIR% !!
    echo.
    echo Error details have been saved to:
    echo %LOG_PATH%
    echo.
    echo ----- ERROR MESSAGE -----
    type %LOG_PATH%
    echo -------------------------
    REM
    del %FULL_PATH%
) ELSE (
    echo.
    echo Backup complete for: %TARGET_DIR%
    REM 
    del %LOG_PATH%
)
GOTO :EOF