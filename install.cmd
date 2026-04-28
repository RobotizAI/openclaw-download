@echo off
setlocal EnableExtensions

title OpenClaw Office RobotizAI - Instalador Windows WSL

net session >nul 2>&1
if errorlevel 1 (
  echo Solicitando permissao de Administrador...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%ComSpec%' -ArgumentList '/c ""%~f0""' -Verb RunAs"
  exit /b
)

set "DISTRO=RobotizAI-OpenClaw"
set "BASE=%LOCALAPPDATA%\RobotizAI\WSL"
set "INSTALLDIR=%BASE%\%DISTRO%"
set "TAR=%TEMP%\ubuntu-24.04-wsl-rootfs.tar.gz"
set "ROOTFS=https://cloud-images.ubuntu.com/wsl/releases/24.04/current/ubuntu-noble-wsl-amd64-wsl.rootfs.tar.gz"

echo.
echo =============================================
echo  OpenClaw Office RobotizAI - Windows WSL v81
echo =============================================
echo.

echo [1/7] Ativando WSL 2...
wsl --install --no-distribution --web-download
wsl --set-default-version 2
wsl --update --web-download

echo.
echo [2/7] Criando pasta de instalacao...
mkdir "%BASE%" >nul 2>&1

echo.
echo [3/7] Verificando ambiente Linux RobotizAI...
wsl -d "%DISTRO%" -u root -- true >nul 2>&1

if errorlevel 1 (
  echo Baixando Ubuntu 24.04 LTS para WSL...
  if exist "%TAR%" del /f /q "%TAR%" >nul 2>&1
  curl.exe -L --fail "%ROOTFS%" -o "%TAR%"
  if errorlevel 1 goto ERRO

  echo Importando Ubuntu 24.04 LTS no WSL...
  wsl --import "%DISTRO%" "%INSTALLDIR%" "%TAR%" --version 2
  if errorlevel 1 goto ERRO
) else (
  echo Ambiente Linux ja existe: %DISTRO%
)

echo.
echo [4/7] Configurando systemd no WSL...
wsl -d "%DISTRO%" -u root -- bash -lc "printf '[boot]\nsystemd=true\n\n[user]\ndefault=root\n' > /etc/wsl.conf"
if errorlevel 1 goto ERRO

wsl --shutdown
timeout /t 3 /nobreak >nul

echo.
echo [5/7] Instalando dependencias Linux...
wsl -d "%DISTRO%" -u root -- bash -lc "set -e; export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a; apt-get update; apt-get upgrade -y; apt-get install -y sudo curl git ca-certificates gnupg unzip build-essential python3 python3-venv python3-pip xdg-utils"
if errorlevel 1 goto ERRO

echo.
echo [6/7] Instalando Node.js 24...
wsl -d "%DISTRO%" -u root -- bash -lc "set -e; curl -fsSL https://deb.nodesource.com/setup_24.x | bash -; export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a; apt-get install -y nodejs; node -v; npm -v"
if errorlevel 1 goto ERRO

echo.
echo [7/7] Instalando OpenClaw Office RobotizAI...
wsl -d "%DISTRO%" -u root -- bash -lc "set -e; curl -fsSL https://raw.githubusercontent.com/RobotizAI/openclaw-download/main/install.sh | bash"
if errorlevel 1 goto ERRO

echo.
echo Reiniciando gateway...
wsl -d "%DISTRO%" -u root -- bash -lc "openclaw gateway restart || true"

echo.
echo Abrindo dashboard...
wsl -d "%DISTRO%" -u root -- bash -lc "nohup openclaw dashboard >/tmp/openclaw-dashboard.log 2>&1 &"
start "" "http://127.0.0.1:18789/"

echo.
echo ============================================
echo  Instalacao concluida com sucesso!
echo ============================================
echo.
echo Para abrir novamente:
echo wsl -d %DISTRO% -u root -- openclaw dashboard
echo.
exit /b 0

:ERRO
echo.
echo ============================================
echo  ERRO: instalacao interrompida.
echo ============================================
echo.
echo Se esta for a primeira instalacao do WSL no Windows,
echo reinicie o computador e execute este install.cmd novamente.
echo.
exit /b 1
