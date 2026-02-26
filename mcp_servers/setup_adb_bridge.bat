@echo off
echo MCP ADB Bridge Setup
echo ====================

REM Check if Python is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.8+ from https://python.org
    pause
    exit /b 1
)

REM Check if pip is available
pip --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: pip is not available
    echo Please install pip
    pause
    exit /b 1
)

REM Check if ADB is available
adb version >nul 2>&1
if %errorlevel% neq 0 (
    echo WARNING: ADB is not found
    echo Please install Android SDK Platform Tools
    echo Download from: https://developer.android.com/studio/releases/platform-tools
    echo Or add ADB to your PATH environment variable
    pause
)

echo Installing Python dependencies...
pip install -r requirements.txt

if %errorlevel% neq 0 (
    echo ERROR: Failed to install dependencies
    pause
    exit /b 1
)

echo.
echo Setup complete!
echo.
echo To run the ADB Bridge:
echo     python adb_bridge.py
echo.
echo Make sure:
echo 1. Android device is connected via USB
echo 2. USB debugging is enabled on the device
echo 3. OraFlow Desktop app is running
echo.
pause
