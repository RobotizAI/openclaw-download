#!/usr/bin/env bash

# =================================================
# OpenClaw Office RobotizAI Installer - Linux
# =================================================

set -euo pipefail

REPO_URL="https://github.com/RobotizAI/openclaw-download.git"
TMP_DIR="/tmp/openclaw-install"
DEST_DIR="$HOME/.openclaw"
SOURCE_DIR=""
TOTAL_STEPS=11
CURRENT_STEP=0
BAR_WIDTH=34

banner() {
  echo ""
  echo " ╔════════════════════════════════════════════╗"
  echo " ║      OpenClaw RobotizAI Installer v79      ║"
  echo " ╚════════════════════════════════════════════╝"
  echo ""
}

print_bar() {
  local current="$1"
  local total="$2"
  local label="$3"
  local percent=$(( current * 100 / total ))
  local filled=$(( BAR_WIDTH * current / total ))
  local empty=$(( BAR_WIDTH - filled ))
  local fill
  local rest
  fill=$(printf '%*s' "$filled" '' | tr ' ' '=')
  rest=$(printf '%*s' "$empty" '')
  printf '\n[%s%s] %3d%%  %s\n' "$fill" "$rest" "$percent" "$label"
}

next_step() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  print_bar "$CURRENT_STEP" "$TOTAL_STEPS" "$1"
}

info() {
  printf '➜ %s\n' "$1"
}

success() {
  printf '✔ %s\n' "$1"
}

warn() {
  printf '⚠ %s\n' "$1"
}

fail() {
  printf '❌ %s\n' "$1" >&2
  exit 1
}

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

cleanup_on_error() {
  local exit_code=$?
  if [ "$exit_code" -ne 0 ]; then
    echo ""
    warn "A instalação falhou."
  fi
  exit "$exit_code"
}
trap cleanup_on_error EXIT

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

package_installed() {
  dpkg -s "$1" >/dev/null 2>&1
}

node_major() {
  if command -v node >/dev/null 2>&1; then
    node -v | sed -E 's/^v([0-9]+).*/\1/'
  else
    echo 0
  fi
}

base_packages_ok() {
  command_exists curl \
    && command_exists git \
    && command_exists python3 \
    && command_exists pip3 \
    && python3 -m venv --help >/dev/null 2>&1 \
    && package_installed ca-certificates
}

prepare_source() {
  if [ -d "$TMP_DIR/.git" ]; then
    info "Repositório temporário já existe; atualizando..."
    git -C "$TMP_DIR" fetch --depth 1 origin
    git -C "$TMP_DIR" reset --hard origin/HEAD
  else
    rm -rf "$TMP_DIR"
    git clone --depth 1 "$REPO_URL" "$TMP_DIR"
  fi

  if [ -d "$TMP_DIR/.openclaw" ]; then
    SOURCE_DIR="$TMP_DIR/.openclaw"
  elif [ -d "$TMP_DIR/openclaw" ]; then
    SOURCE_DIR="$TMP_DIR/openclaw"
  else
    fail "Nenhuma pasta .openclaw foi encontrada no repositório."
  fi

  success "Pacote RobotizAI localizado em: $SOURCE_DIR"
}

install_base_packages_linux() {
  if base_packages_ok; then
    success "Dependências base já estão instaladas; pulando reinstalação."
    return 0
  fi

  export DEBIAN_FRONTEND=noninteractive
  as_root apt-get update
  as_root apt-get -o Dpkg::Progress-Fancy=1 install -y \
    curl git ca-certificates python3 python3-pip python3-venv

  base_packages_ok || fail "As dependências base não foram instaladas corretamente."
  success "Dependências base instaladas/verificadas."
}

install_or_upgrade_node_linux() {
  local current_major
  current_major="$(node_major)"

  if command_exists node && command_exists npm; then
    if [ "$current_major" -ge 24 ]; then
      success "Node $(node -v) e npm $(npm -v) já atendem ao requisito mínimo; pulando reinstalação."
      return 0
    fi
  fi

  info "Instalando Node.js 24.x via NodeSource..."
  curl -fsSL https://deb.nodesource.com/setup_24.x -o "$TMP_DIR/nodesource_setup.sh"
  as_root bash "$TMP_DIR/nodesource_setup.sh"
  export DEBIAN_FRONTEND=noninteractive
  as_root apt-get -o Dpkg::Progress-Fancy=1 install -y nodejs

  command_exists node || fail "Node.js não foi instalado corretamente."
  command_exists npm || fail "npm não foi instalado corretamente."

  if [ "$(node_major)" -lt 24 ]; then
    fail "A versão instalada do Node é inferior à 24."
  fi

  success "Node $(node -v) e npm $(npm -v) instalados/verificados."
}

openclaw_is_official_cli() {
  if ! command_exists openclaw; then
    return 1
  fi

  local resolved
  resolved="$(readlink -f "$(command -v openclaw)" 2>/dev/null || command -v openclaw)"

  case "$resolved" in
    "$HOME/.openclaw"/*)
      return 1
      ;;
  esac

  openclaw --version >/dev/null 2>&1
}

install_official_openclaw() {
  if openclaw_is_official_cli; then
    success "CLI oficial do OpenClaw já está instalada em: $(command -v openclaw); pulando reinstalação."
    openclaw --version || true
    return 0
  fi

  if [ -e /usr/local/bin/openclaw ]; then
    info "Removendo wrapper antigo em /usr/local/bin/openclaw para evitar conflito..."
    as_root rm -f /usr/local/bin/openclaw
  fi

  info "Instalando OpenClaw oficial com npm install -g openclaw@latest..."
  npm cache verify >/dev/null 2>&1 || true
  export npm_config_loglevel=warn
  export npm_config_fund=false
  export npm_config_audit=false
  export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=2048}"

  as_root env \
    npm_config_loglevel="$npm_config_loglevel" \
    npm_config_fund="$npm_config_fund" \
    npm_config_audit="$npm_config_audit" \
    NODE_OPTIONS="$NODE_OPTIONS" \
    npm install -g --progress=true openclaw@latest

  hash -r

  openclaw_is_official_cli || fail "O comando openclaw não foi encontrado após a instalação oficial."

  success "CLI oficial encontrada em: $(command -v openclaw)"
  openclaw --version || true
}

stage_previous_install() {
  if [ -e "$DEST_DIR" ]; then
    success "Instalação atual detectada em $DEST_DIR; os arquivos serão substituídos individualmente sem apagar a pasta inteira."
  else
    success "Nenhuma instalação anterior em $DEST_DIR; a estrutura oficial será criada na próxima etapa."
  fi
}

initialize_official_home() {
  if [ -d "$DEST_DIR" ]; then
    success "A pasta ~/.openclaw já existe; pulando recriação oficial."
    return 0
  fi

  info "Inicializando a pasta oficial ~/.openclaw com openclaw setup..."
  openclaw setup
  [ -d "$DEST_DIR" ] || fail "O OpenClaw oficial não criou a pasta ~/.openclaw."
  success "Pasta oficial criada com sucesso em $DEST_DIR"
}

replace_with_robotizai_bundle() {
  [ -d "$SOURCE_DIR" ] || fail "A pasta de origem RobotizAI não existe."
  [ -d "$DEST_DIR" ] || fail "A pasta de destino ~/.openclaw não existe."

  info "Substituindo os arquivos da ~/.openclaw pela versão RobotizAI do GitHub..."

  while IFS= read -r -d '' item; do
    local rel
    local target
    rel="${item#"$SOURCE_DIR"/}"
    target="$DEST_DIR/$rel"

    if [ -d "$item" ]; then
      if [ -e "$target" ] && [ ! -d "$target" ]; then
        rm -rf "$target"
      fi
      mkdir -p "$target"
    elif [ -L "$item" ] || [ -f "$item" ]; then
      mkdir -p "$(dirname "$target")"
      if [ -e "$target" ] && [ -d "$target" ] && [ ! -L "$target" ]; then
        rm -rf "$target"
      fi
      cp -a "$item" "$target"
    fi
  done < <(find "$SOURCE_DIR" -mindepth 1 -print0)

  [ -d "$DEST_DIR" ] || fail "A atualização dos arquivos RobotizAI em $DEST_DIR falhou."
  success "Arquivos RobotizAI copiados individualmente para $DEST_DIR"
}

gateway_is_running() {
  openclaw gateway status >/tmp/openclaw-gateway-status.log 2>&1 || return 1
  grep -Eiq 'running|online|connected|ok|healthy|ativo' /tmp/openclaw-gateway-status.log
}

restart_gateway() {
  if gateway_is_running; then
    info "Gateway já está ativo; reiniciando para aplicar a versão RobotizAI..."
  else
    info "Gateway não está ativo; iniciando/reiniciando..."
  fi

  openclaw gateway restart
  success "Gateway reiniciado."
}

onboard_already_done() {
  [ -d "$DEST_DIR" ] && [ -f "$DEST_DIR/openclaw.json" ]
}

run_onboard() {
  if onboard_already_done; then
    success "Estrutura principal do OpenClaw já existe; pulando nova execução do onboard."
    return 0
  fi

  info "Executando openclaw onboard automaticamente..."
  openclaw onboard --install-daemon </dev/tty
  success "Onboarding concluído."
}

dashboard_already_running() {
  pgrep -af "openclaw dashboard" >/dev/null 2>&1
}

open_dashboard() {
  info "Abrindo o dashboard do OpenClaw..."
  rm -f /tmp/openclaw-dashboard.log

  if dashboard_already_running; then
    success "Dashboard já está em execução; pulando nova abertura."
    return 0
  fi

  if command_exists nohup; then
    nohup openclaw dashboard >/tmp/openclaw-dashboard.log 2>&1 &
  else
    openclaw dashboard >/tmp/openclaw-dashboard.log 2>&1 &
  fi

  sleep 8
  success "Dashboard acionado."
}

main() {
  banner

  next_step "Instalando dependências base (curl, git, python3, venv)"
  if command_exists apt-get; then
    install_base_packages_linux
  else
    fail "Este instalador v79 suporta Linux com apt-get (Ubuntu / Debian / Linux Mint)."
  fi

  next_step "Baixando o repositório RobotizAI"
  prepare_source

  next_step "Garantindo Node.js 24 ou superior e npm"
  install_or_upgrade_node_linux

  next_step "Preparando uma instalação oficial limpa do OpenClaw"
  stage_previous_install

  next_step "Instalando a CLI oficial do OpenClaw via npm"
  install_official_openclaw

  next_step "Criando a ~/.openclaw oficial do OpenClaw"
  initialize_official_home

  next_step "Substituindo a ~/.openclaw oficial pela versão RobotizAI"
  replace_with_robotizai_bundle

  next_step "Reiniciando o gateway do OpenClaw"
  restart_gateway

  next_step "Executando openclaw onboard automaticamente"
  run_onboard

  next_step "Abrindo o dashboard do OpenClaw"
  open_dashboard

  next_step "Concluindo"
  rm -rf "$TMP_DIR"
  rm -f /tmp/openclaw-gateway-status.log
  trap - EXIT

  echo ""
  success "Instalação concluída com sucesso!"
  echo ""
  echo "OpenClaw oficial instalado: $(command -v openclaw)"
  echo "Versão do OpenClaw: $(openclaw --version 2>/dev/null || true)"
  echo ""
  echo "🤖 Comandos úteis:"
  echo "  openclaw onboard --install-daemon -> Configurações iniciais do openclaw"
  echo "  openclaw gateway stop -> Finaliza o openclaw"
  echo "  openclaw gateway start -> Inicia o openclaw"
  echo "  openclaw gateway restart -> Reinicia o openclaw"
  echo "  openclaw dashboard -> Abre o openclaw no navegador padrão"
  echo ""
  echo "⚠️ Próximo comando, digite:"
  echo "👉  openclaw onboard --install-daemon"
  echo ""
  echo "⚠️ Depois que concluir as configurações inicias (com openclaw onboard) atualize a página do Openclaw (apertando Ctrl + F5) ou digite o comando:"
  echo "👉  openclaw dashboard"
}

main "$@"
