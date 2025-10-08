@echo off
setlocal enabledelayedexpansion

:: Configuration
set "SOURCE_DIR=%~dp0"
set "TEMP_DIR=%SOURCE_DIR%extracted"
set "HTMLS_DIR=%SOURCE_DIR%html_files"
set "LOG_DIR=%SOURCE_DIR%log_htmls"
set "PYTHON_SCRIPT=%SOURCE_DIR%collect_tenhou_logs_html.py"

echo ========================================
echo Complete Pipeline: Extract and Process Tenhou Logs
echo ========================================
echo.

:: Check if 7-Zip is installed
set "SEVENZIP="
if exist "C:\Program Files\7-Zip\7z.exe" set "SEVENZIP=C:\Program Files\7-Zip\7z.exe"
if exist "C:\Program Files (x86)\7-Zip\7z.exe" set "SEVENZIP=C:\Program Files (x86)\7-Zip\7z.exe"

if "%SEVENZIP%"=="" (
    echo ERROR: 7-Zip not found. Please install 7-Zip from https://www.7-zip.org/
    pause
    exit /b 1
)

:: Check if Python is installed
python --version >nul 2>&1
if !errorlevel! neq 0 (
    echo ERROR: Python not found. Please install Python from https://www.python.org/
    echo Make sure to check "Add Python to PATH" during installation.
    pause
    exit /b 1
)

echo [OK] 7-Zip found: %SEVENZIP%
for /f "tokens=*" %%i in ('python --version 2^>^&1') do set "PYTHON_VER=%%i"
echo [OK] Python found: %PYTHON_VER%
echo.

:: Check if Python script exists
if not exist "%PYTHON_SCRIPT%" (
    echo ERROR: Python script not found: collect_tenhou_logs_html.py
    echo Please make sure collect_tenhou_logs_html.py is in the same directory as this batch file.
    pause
    exit /b 1
)

echo [OK] Python script found: collect_tenhou_logs_html.py
echo.

:: Create directories if they don't exist
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"
if not exist "%HTMLS_DIR%" mkdir "%HTMLS_DIR%"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

echo ========================================
echo STEP 1: Extracting scc*.html.gz from ZIP files
echo ========================================
echo.

:: Loop through all scraw*.zip files
set "zip_count=0"
for %%F in ("%SOURCE_DIR%scraw*.zip") do set /a zip_count+=1

if %zip_count%==0 (
    echo No scraw*.zip files found in current directory.
    pause
    exit /b 0
)

echo Found %zip_count% scraw*.zip file(s)
echo.

for %%F in ("%SOURCE_DIR%scraw*.zip") do (
    echo Processing: %%~nxF
    
    :: Extract year from filename (scraw2024.zip -> 2024)
    set "filename=%%~nF"
    set "year=!filename:scraw=!"
    
    echo   Year detected: !year!
    
    :: Extract all scc*.html.gz files from the year directory
    "%SEVENZIP%" e "%%F" "!year!\scc*.html.gz" -o"%TEMP_DIR%" -y >nul 2>&1
    
    if !errorlevel! equ 0 (
        echo   [SUCCESS] Extracted scc files from %%~nxF
    ) else (
        echo   [WARNING] No scc*.html.gz files found or extraction failed for %%~nxF
    )
    echo.
)

echo ========================================
echo STEP 2: Decompressing .html.gz files
echo ========================================
echo.

:: Count extracted .html.gz files
set "gz_count=0"
for %%F in ("%TEMP_DIR%\*.html.gz") do set /a gz_count+=1

if %gz_count%==0 (
    echo No .html.gz files found to decompress.
    echo Check if the ZIP files contain scc*.html.gz files.
    pause
    exit /b 0
)

echo Found %gz_count% .html.gz file(s) to decompress
echo.

:: Loop through all .html.gz files and decompress them
for %%F in ("%TEMP_DIR%\*.html.gz") do (
    echo Processing: %%~nxF
    
    :: Decompress the .gz file to output directory
    "%SEVENZIP%" e "%%F" -o"%HTMLS_DIR%" -y >nul 2>&1
    
    if !errorlevel! equ 0 (
        echo   [SUCCESS] Decompressed to: %%~nF
    ) else (
        echo   [ERROR] Failed to decompress: %%~nxF
    )
)

echo.

:: Count decompressed HTML files
set /a html_count=0
for %%F in ("%HTMLS_DIR%\*.html") do set /a html_count+=1

if %html_count%==0 (
    echo No HTML files were created.
    pause
    exit /b 0
)

echo [SUCCESS] %html_count% HTML file(s) decompressed
echo.

echo ========================================
echo STEP 3: Extracting Tenhou URLs
echo ========================================
echo.

:: Run Python script with html_files directory and log_htmls directory as parameters
echo Running Python script to extract URLs...
echo Command: python "%PYTHON_SCRIPT%" "%HTMLS_DIR%" "%LOG_DIR%"
echo.
python "%PYTHON_SCRIPT%" "%HTMLS_DIR%" "%LOG_DIR%"

if !errorlevel! neq 0 (
    echo.
    echo [ERROR] Python script failed with error code: !errorlevel!
    pause
    exit /b !errorlevel!
)

echo.
echo ========================================
echo Pipeline Complete!
echo ========================================
echo.

:: Clean up temporary directory
echo Cleaning up temporary files...
if exist "%TEMP_DIR%" (
    rmdir /s /q "%TEMP_DIR%"
    if !errorlevel! equ 0 (
        echo [SUCCESS] Deleted temporary directory: extracted
    ) else (
        echo [WARNING] Could not delete temporary directory: extracted
    )
) else (
    echo [INFO] No temporary directory to clean up
)
echo.

echo Final output:
echo   - %HTMLS_DIR%  (HTML files)
echo   - %LOG_DIR%  (tenhou_log_urls_*.txt files)
echo.

pause