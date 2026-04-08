import json
import os
import time
import subprocess

SESSION_FILE = "/home/pc/.openclaw/agents/main/sessions/sessions.json"
SET_STATE_CMD = ["python3", "/home/pc/.openclaw/workspace/Star-Office-UI/set_state.py"]

last_state = None

def set_state(state, detail):
    global last_state
    if last_state != state:
        subprocess.run(SET_STATE_CMD + [state, detail])
        last_state = state

while True:
    try:
        if os.path.exists(SESSION_FILE):
            with open(SESSION_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
            main_session = data.get("agent:main:main", {})
            
            system_sent = main_session.get("systemSent", True)
            updated_at = main_session.get("updatedAt", 0) / 1000.0
            status = main_session.get("status", "idle")
            
            current_time = time.time()
            
            # Regra 4 e 5: Pensando, executando ou erro = Escritório executing
            if status == "running":
                set_state("executing", "Pensando/Executando...")
            # Regra 2: Usuário enviou mensagem (systemSent == False) = Escritório executing
            elif not system_sent:
                set_state("executing", "Mensagem recebida...")
            # Regra 1: Mais de 3 min sem interação = Quarto syncing
            elif (current_time - updated_at) > 180:
                set_state("syncing", "Inatividade > 3 min")
            # Regra 3: Agente respondeu (systemSent == True) = Sala idle
            elif system_sent:
                set_state("idle", "Aguardando na sala")
                
    except Exception:
        pass
    time.sleep(1)
