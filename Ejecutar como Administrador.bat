@echo off
:: ============================================================
:: Optimizador Universal de Notebooks
:: Doble click para ejecutar - solicita UAC automaticamente
:: Compatible con rutas con espacios (OneDrive, Escritorio, etc.)
:: ============================================================

setlocal enabledelayedexpansion

:: Cambiar al directorio del .bat
cd /d "%~dp0"

:: Verificar si ya somos administrador
net session >nul 2>&1
if %errorLevel% == 0 goto :run

:: No somos admin: re-lanzar con elevacion UAC
powershell -NoProfile -Command ^
  "Start-Process cmd -ArgumentList '/c cd /d \"%~dp0\" && \"%~f0\"' -Verb RunAs -ErrorAction Stop" ^
  2>nul
if %errorLevel% neq 0 (
    echo.
    echo   No se pudo elevar automaticamente.
    echo   Hace click derecho en este archivo y selecciona
    echo   "Ejecutar como administrador".
    echo.
    pause
    exit /b 1
)
exit /b

:run
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0main.ps1"
