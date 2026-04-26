@echo off
setlocal

set "ROOT_DIR=%~dp0"
cd /d "%ROOT_DIR%"

echo [1/2] Configurando CMake...
cmake -S . -B build
if errorlevel 1 goto :error

echo [2/2] Compilando API em Release...
cmake --build build --config Release
if errorlevel 1 goto :error

echo.
echo API compilada com sucesso.
echo Executavel: build\Release\soundpad_deck.exe
exit /b 0

:error
echo.
echo Falha ao compilar a API.
exit /b 1
