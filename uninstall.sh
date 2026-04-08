#!/bin/bash

DEST_DIR="$HOME/.openclaw"

echo ""
echo "  ╔══════════════════════════════════╗"
echo "  ║    OpenClaw Uninstaller v2.0     ║"
echo "  ╚══════════════════════════════════╝"
echo ""

if [ ! -d "$DEST_DIR" ]; then
  echo "ℹ️ OpenClaw não está instalado."
  exit 0
fi

printf "Deseja remover $DEST_DIR? (s/N): "
read -r RESP

if [[ "$RESP" != "s" && "$RESP" != "S" ]]; then
  echo "Cancelado."
  exit 0
fi

rm -rf "$DEST_DIR"

echo "✅ Removido com sucesso!"
