# 🦞 OpenClaw Office RobotizAI v79
Este é o repositório oficial do Office RobotizAI com OpenClaw original e interface visual interativa nativa.

### 🧑‍💻 Desenvolvedor
Desenvolvido por **Carlos Stringuetti**, fundador da **RobotizAI.com | Inteligência Artificial**.<br>
Este sistema utiliza o OpenClaw oficial e o Star Office UI como base para interface visual do escritório.

### 🛒 Loja - Personagens e Escritórios
O Openclaw Office Robotizai vem com **3 personagens** e **4 escritórios/casas** (Vera, Antonio e Lobster) padrão para você escolher!<br>
Na nossa Loja Online você vai encontrar outros personagens, escritorios/casas para download como por exemplo o **Goku (Dragon Ball Z)**.<br>
Visite nossa **Loja Online** oficial em **https://RobotzAI.com/loja-openclaw** e veja todas as opções.<br>

---
<details open>
<summary>💼 Este é o Escritório da Vera</summary><br>
  
![Screenshot Escritório Vera](Screenshots/Vera%20-%20Openclaw%20Office%20RobotizAI.jpeg)
</details>

<details>
<summary>💼 Clique aqui para ver o escritório do Antonio</summary><br>
  
![Screenshot Escritório Antonio](Screenshots/Antonio%20-%20Openclaw%20Office%20RobotizAI.jpeg)
</details>

<details>
<summary>🏠 Clique aqui para ver a casa (original) do Lobster</summary><br>
  
![Screenshot Escritório Lobster (original)](Screenshots/Lobster%20(original)%20-%20Openclaw%20Office%20RobotizAI.jpeg)
</details>

<details>
<summary>🏠 Clique para ver a casa (snowing) do Lobster</summary><br>
  
![Screenshot Escritório Lobster (snowing)](Screenshots/Lobster%20(snowing)%20-%20Openclaw%20Office%20RobotizAI.jpeg)
</details>

<details>
<summary>🏠 Clique para ver a casa do Goku (dragonball z)</summary><br>

🛒 Disponível na [Loja Online](https://robotizai.com/loja)

![Screenshot Escritório Lobster (snowing)](Screenshots/Goku%20(dragonball%20z)%20-%20Openclaw%20Office%20RobotizAI.jpeg)

</details>

---

#### 📑 Requisitos mínimos para rodar o Openclaw Office RobotizAI 
<details>
<summary>(clique para ver mais)</summary>
  
Estes são os requisitos mínimos recomendados para o Openclaw Office RobotizAI funcionar na sua máquina (configurações superiores melhoram o desempenho consideravelmente).

#### 🐧 Linux Mint / Ubuntu / Debian
```
  **🌐⚙️ VM (Virtualbox) com API:** Processador CPU 1 núcleos, 1GB RAM, GPU VRAM não obrigatorio (bom para rodar vários Openclaw Office RobotizAI ao mesmo tempo).<br>

  **💻⚙️ Local com API:** Processador 2 núcleos, 1GB RAM, GPU VRAM não obrigatorio (útil para rodar em notebook/pc antigo).<br>

  **🌐 VM (Virtualbox) sem API:** Processador 4 núcleos, 8GB RAM, GPU 8GB VRAM obrigatorio (bom para rodar vários Openclaw Office RobotizAI ao mesmo tempo em notebook/pc potente ou servidor externo zerando custos com tokens).<br>

  **💻 Local sem API:** Processador 4 núcleos, 8GB RAM, GPU 8GB VRAM obrigatorio (útil para rodar em notebook/pc ou servidor potente e zerar custos com tokens).<br>
```

#### 🪟 Windows
```
  **🌐⚙️ VM (Virtualbox) com API:** Processador CPU 2 núcleos, 2GB RAM, GPU VRAM não obrigatorio (bom para rodar vários Openclaw Office RobotizAI ao mesmo tempo).<br>

  **💻⚙️ Local com API:** Processador 2 núcleos, 2GB RAM, GPU VRAM não obrigatorio (útil para rodar em notebook/pc antigo).<br>

  **🌐 VM (Virtualbox) sem API:** Processador 4 núcleos, 8GB RAM, GPU 8GB VRAM obrigatorio (bom para rodar vários Openclaw Office RobotizAI ao mesmo tempo em notebook/pc potente ou servidor externo zerando custos com tokens).<br>

  **💻 Local sem API:** Processador 4 núcleos, 8GB RAM, GPU 8GB VRAM obrigatorio (útil para rodar em notebook/pc ou servidor potente e zerar custos com tokens).<br>
</details>
```

---

#### ⚠️ Aviso
O instalador substitui automaticamente arquivos no diretório `~/.openclaw`, caso já exista uma versão do openclaw instalada, será substituida automaticamente por um novo opeclaw.

## 🚀 Instalação Completa Automatizada

#### 🐧 Linux Mint / Ubuntu / Debian

bash
```
curl -fsSL https://raw.githubusercontent.com/RobotizAI/openclaw-download/main/install.sh | bash
```

##### 🐧 Clonar e rodar localmente

bash
```
git clone https://github.com/RobotizAI/openclaw-download
cd openclaw-download
bash install.sh
```

#### 🪟 Windows (Powershell)

powershell
```
iwr -useb https://raw.githubusercontent.com/RobotizAI/openclaw-download/main/install.ps1 | iex
```

---

### ✅ Como o instalador funciona
<details>
<summary>(clique para ver mais)</summary>
  
No Linux Mint / Ubuntu / Debian, o instalador faz isso automaticamente, sem interação:

1. instala os pré-requisitos necessários
2. garante **Node.js 24 ou superior**
3. instala o **OpenClaw oficial** com `npm install -g openclaw@latest`
4. executa `openclaw setup` para criar a pasta oficial `~/.openclaw`
5. substitui a pasta recém-criada pela pasta `.openclaw` deste repositório
6. executa `openclaw gateway restart`
7. executa `openclaw dashboard`
8. executa `openclaw onboard --install-daemon` automaticamente

O comando `openclaw` continua sendo o **OpenClaw oficial**, não um wrapper customizado.
</details>

---

#### 📦 O que está incluído
<details>
<summary>(clique para ver mais)</summary>
  
- Configuração principal do OpenClaw (`.openclaw/openclaw.json`)
- Star Office UI (`.openclaw/workspace/Star-Office-UI/`)
- Extensões do browser (`.openclaw/extensions/`)
- Completions de terminal (bash, zsh, fish, PowerShell)
- Configuração de agentes e workspace
</details>

---

### 📍 Onde é instalado

<details>
<summary>(clique para ver mais)</summary>
  
| Sistema | Diretório |
|---|---|
| 🐧 Linux / macOS | `~/.openclaw` |
| 🪟 Windows | `%USERPROFILE%\.openclaw` |

</details>

---

### 🗑️ Desinstalação

<details>
<summary>(clique para ver mais)</summary>

#### 🐧 Linux / macOS

bash
```
curl -fsSL https://raw.githubusercontent.com/RobotizAI/openclaw-download/main/uninstall.sh | bash
```

#### 🪟 Windows

powershell
```
irm https://raw.githubusercontent.com/RobotizAI/openclaw-download/main/uninstall.ps1 | iex
```

</details>

---

### 📁 Estrutura do repositório

<details>
<summary>(clique para ver mais)</summary>
  
text
```
.
├── .openclaw/              ← arquivos instalados em ~/.openclaw
│   ├── openclaw.json
│   ├── agents/
│   ├── browser/
│   ├── canvas/
│   ├── completions/
│   ├── extensions/
│   ├── cron/
│   ├── devices/
│   └── workspace/
│       └── Star-Office-UI/ ← interface Star UI
├── install.sh              ← instalador Linux Mint / Ubuntu / Debian
├── install.ps1             ← instalador Windows
├── uninstall.sh            ← desinstalador Linux/macOS
├── uninstall.ps1           ← desinstalador Windows
└── README.md
```
</details>

---
