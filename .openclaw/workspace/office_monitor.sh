#!/bin/bash
# office_monitor.sh - Monitoramento do Star Office UI (Zero Tokens)
# Executado periodicamente via crontab do Sistema Operacional

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
WORKSPACE="/home/pc/.openclaw/workspace"

cd "$WORKSPACE" || exit 1

# 1. Garante que o UI esteja rodando
UI_IS_OPERATIONAL=false
if pgrep -f "python3 app.py" > /dev/null
then
    UI_IS_OPERATIONAL=true
else
    pkill -f "python3 app.py"
    (cd Star-Office-UI && source venv/bin/activate && cd backend && python3 app.py > /dev/null 2>&1 &)
    UI_IS_OPERATIONAL=true
fi

# 2. Garante que o session watcher esteja rodando (Zero Token UI State Sync)
if ! pgrep -f "python3 Star-Office-UI/session_watcher.py" > /dev/null
then
    python3 Star-Office-UI/session_watcher.py > /dev/null 2>&1 &
fi

# 3. Monitoramento de Inatividade para mudança de posição automática
if [ "$UI_IS_OPERATIONAL" = true ]; then
    STATE_FILE="Star-Office-UI/state.json"
    
    if [ -f "$STATE_FILE" ]; then
        # Pega a data de modificação do state.json
        LAST_MODIFIED=$(stat -c %Y "$STATE_FILE")
        CURRENT_TIME=$(date +%s)
        INACTIVITY=$((CURRENT_TIME - LAST_MODIFIED))
        
        # Pega o estado atual
        CURRENT_STATE=$(grep -o '"state": "[^"]*"' "$STATE_FILE" | cut -d'"' -f4)
        
        # Se estiver inativo por mais de 3 minutos (180s) e NÃO estiver em idle/syncing
        if [ "$INACTIVITY" -gt 180 ]; then
            if [ "$CURRENT_STATE" != "idle" ] && [ "$CURRENT_STATE" != "syncing" ]; then
                python3 Star-Office-UI/set_state.py syncing "Atualizando Posição" > /dev/null 2>&1
            elif [ "$CURRENT_STATE" = "syncing" ] && [ "$INACTIVITY" -gt 240 ]; then
                # Se ficou em syncing por muito tempo, volta para idle (Sala Breakroom)
                python3 Star-Office-UI/set_state.py idle "Esperando na sala" > /dev/null 2>&1
            fi
        fi
    fi
fi
