@echo off
echo ====================================
echo    LiveChat - Elixir Chat Server
echo ====================================
echo.

where elixir >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Elixir is not installed.
    echo.
    echo Installation:
    echo   1. Visit https://elixir-lang.org/install.html
    echo   2. Download and install the Windows Installer
    echo.
    pause
    exit /b 1
)

echo [1/3] Installing dependencies...
call mix deps.get

echo.
echo [2/3] Building assets...
call mix assets.setup
call mix assets.build

echo.
echo [3/3] Starting server...
echo.
echo  Open http://localhost:4000 in your browser!
echo  Stop server: Ctrl+C
echo.
call mix phx.server
