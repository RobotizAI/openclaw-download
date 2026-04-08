# TOOLS.md - Local Notes

Skills definem como as ferramentas funcionam. Este arquivo é para suas especificações — detalhes únicos da sua configuração.

## O que vai aqui:

- Nomes e localizações de câmeras
- Hosts SSH e apelidos
- Vozes preferidas para TTS
- Nomes de alto-falantes/salas
- Apelidos de dispositivos
- Qualquer coisa específica do ambiente
- **Como usar a Web UI do OpenClaw (Gateway Dashboard) e automação de navegador:** Para detalhes, consulte `docs/web_ui_details.md`.

## Exemplos:

```markdown
### Cameras

- living-room → Main area, 180° wide angle
- front-door → Entrance, motion-triggered

### SSH

- home-server → 192.168.1.100, user: admin

### TTS

- Preferred voice: "Nova" (warm, slightly British)
- Default speaker: Kitchen HomePod
```

## Por que separado?

Skills são compartilhadas. Sua configuração é sua. Manter separados significa que você pode atualizar skills sem perder suas notas, e compartilhar skills sem expor sua infraestrutura. 

---

Adicione o que te ajuda a fazer seu trabalho. Esta é sua "cola".

---

# Para iniciar ou reiniciar o seu escritório Star Office UI:
Caso o usuário solicite iniciar ou reiniciar o escritorio, execute o passo a passo, teste para ver se funcionou corretamente e só depois responda no chat. Sempre siga todas as estapas uma por uma, uma de cada vez para garantir que tudo esta funcionado corretamente, todas as estapas são essenciais para o correto funcionamento e melhor experiencia do usuário. É obrigatorio segir todas as 14 etapas.

1- Verifique se a pasta /home/pc/.openclaw/workspace/Star-Office-UI/ existe.
2- Verifique se o ambiente .venv existe e se .venv/bin/python3 funciona.
3- Encerre qualquer instância anterior do backend/app.py.
4- Inicie novamente o backend/app.py usando o Python do .venv.
5- Aguarde alguns segundos.
6- Confirme que o processo backend/app.py está rodando.
7- Confirme que a porta 19000 está em escuta.
8- Confirme que http://127.0.0.1:19000/ responde corretamente.
9- Se falhar, leia /tmp/star_office.log, aplique as correções necessárias, reinicie e teste novamente.
10- Verifique se o backend/app.py esta funcionando corretamente, se não estiver reinicie para funcionar corretamente.
11- Verifique se o /home/pc/.openclaw/workspace/Star-Office-UI/session_watcher.py esta funcionando corretamente, se não estiver reinicie para funcionar corretamente.
12- Verifique se o session_watcher.py esta rodando corretamente em segundo plano, se não estiver reinicie para funcionar corretamente.
13- Verifique se o processo daemon esta rodando corretamente em segundo plano, se não estiver reinicie para funcionar corretamente.
14- Só responda ao usuário quando tudo estiver funcionando corretamente.

```bash
cd /home/pc/.openclaw/workspace/Star-Office-UI/ || exit 1
test -x .venv/bin/python3 || exit 1
pkill -f "backend/app.py" || true
sleep 2
.venv/bin/python3 backend/app.py > /tmp/star_office.log 2>&1 &
sleep 8
pgrep -af "backend/app.py" >/dev/null || { tail -n 80 /tmp/star_office.log; exit 1; }
ss -ltn | grep ":19000" >/dev/null || { tail -n 80 /tmp/star_office.log; exit 1; }
curl -fsS http://127.0.0.1:19000/ >/dev/null || { tail -n 80 /tmp/star_office.log; exit 1; }
