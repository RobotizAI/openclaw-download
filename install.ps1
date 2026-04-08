Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

try {
    [Console]::InputEncoding  = [System.Text.UTF8Encoding]::new($false)
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    chcp 65001 > $null
} catch {
}

try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
} catch {
}

$script:RepoUrl = 'https://github.com/RobotizAI/openclaw-download.git'
$script:TmpDir = Join-Path $env:TEMP 'openclaw-install'
$script:DestDir = Join-Path $HOME '.openclaw'
$script:SourceDir = $null
$script:OpenClawCmd = $null
$script:TotalSteps = 11
$script:CurrentStep = 0
$script:BarWidth = 34
$script:InstallSucceeded = $false

function Show-Banner {
    Write-Host ''
    Write-Host ' ====================================================' 
    Write-Host '     OpenClaw RobotizAI Installer v79 - Windows'
    Write-Host ' ====================================================' 
    Write-Host ''
}

function Show-Bar {
    param(
        [int]$Current,
        [int]$Total,
        [string]$Label
    )

    $percent = [math]::Floor(($Current * 100) / $Total)
    $filled = [math]::Floor(($script:BarWidth * $Current) / $Total)
    $empty = $script:BarWidth - $filled
    $fill = ('=' * $filled)
    $rest = (' ' * $empty)

    Write-Host ''
    Write-Host ('[{0}{1}] {2,3}%  {3}' -f $fill, $rest, $percent, $Label)
}

function Next-Step {
    param([string]$Label)
    $script:CurrentStep++
    Show-Bar -Current $script:CurrentStep -Total $script:TotalSteps -Label $Label
}

function Info {
    param([string]$Message)
    Write-Host ('[INFO] {0}' -f $Message)
}

function Success {
    param([string]$Message)
    Write-Host ('[ OK ] {0}' -f $Message)
}

function Warn-Message {
    param([string]$Message)
    Write-Warning $Message
}

function Fail {
    param([string]$Message)
    throw $Message
}

function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = New-Object System.Collections.Generic.List[string]

    foreach ($segment in @($machinePath, $userPath, $env:Path)) {
        if ([string]::IsNullOrWhiteSpace($segment)) { continue }
        foreach ($item in ($segment -split ';')) {
            if (-not [string]::IsNullOrWhiteSpace($item)) {
                $trimmed = $item.Trim()
                if (-not $parts.Contains($trimmed)) {
                    [void]$parts.Add($trimmed)
                }
            }
        }
    }

    $env:Path = ($parts -join ';')
}

function Test-Command {
    param([string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-NodeMajor {
    if (Test-Command 'node') {
        $v = (& node --version 2>$null)
        if ($v -match '^v(\d+)') {
            return [int]$Matches[1]
        }
    }
    return 0
}

function Test-IsAdministrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-WithWinget {
    param(
        [string[]]$Ids,
        [string]$DisplayName
    )

    if (-not (Test-Command 'winget')) { return $false }

    foreach ($id in $Ids) {
        $args = @(
            'install', '--id', $id, '-e', '--source', 'winget',
            '--accept-package-agreements', '--accept-source-agreements', '--silent'
        )
        if (Test-IsAdministrator) {
            $args += @('--scope', 'machine')
        }

        & winget @args
        if ($LASTEXITCODE -eq 0) {
            Refresh-Path
            return $true
        }
    }

    return $false
}

function Install-WithChoco {
    param(
        [string[]]$Packages,
        [string]$DisplayName
    )

    if (-not (Test-Command 'choco')) { return $false }

    foreach ($pkg in $Packages) {
        & choco install $pkg -y --no-progress
        if ($LASTEXITCODE -eq 0) {
            Refresh-Path
            return $true
        }
    }

    return $false
}

function Install-WithScoop {
    param(
        [string[]]$Packages,
        [string]$DisplayName
    )

    if (-not (Test-Command 'scoop')) { return $false }

    foreach ($pkg in $Packages) {
        & scoop install $pkg
        if ($LASTEXITCODE -eq 0) {
            Refresh-Path
            return $true
        }
    }

    return $false
}

function Install-PackageIfMissing {
    param(
        [string]$CommandName,
        [string]$DisplayName,
        [string[]]$WingetIds,
        [string[]]$ChocoPackages,
        [string[]]$ScoopPackages
    )

    if (Test-Command $CommandName) {
        return
    }

    Info "Instalando $DisplayName..."

    if (Install-WithWinget -Ids $WingetIds -DisplayName $DisplayName) { return }
    if (Install-WithChoco -Packages $ChocoPackages -DisplayName $DisplayName) { return }
    if (Install-WithScoop -Packages $ScoopPackages -DisplayName $DisplayName) { return }

    Fail "Não foi possível instalar $DisplayName automaticamente. Instale manualmente e execute novamente."
}

function Prepare-Source {
    if (Test-Path (Join-Path $script:TmpDir '.git')) {
        Info 'Repositório temporário já existe; atualizando...'
        & git -C $script:TmpDir fetch --depth 1 origin
        if ($LASTEXITCODE -ne 0) { Fail 'Falha ao atualizar o repositório temporário.' }
        & git -C $script:TmpDir reset --hard origin/HEAD
        if ($LASTEXITCODE -ne 0) { Fail 'Falha ao resetar o repositório temporário.' }
    } else {
        if (Test-Path $script:TmpDir) {
            Remove-Item -LiteralPath $script:TmpDir -Recurse -Force
        }
        & git clone --depth 1 $script:RepoUrl $script:TmpDir
        if ($LASTEXITCODE -ne 0) { Fail 'Falha ao clonar o repositório RobotizAI.' }
    }

    $candidateA = Join-Path $script:TmpDir '.openclaw'
    $candidateB = Join-Path $script:TmpDir 'openclaw'

    if (Test-Path $candidateA) {
        $script:SourceDir = $candidateA
    } elseif (Test-Path $candidateB) {
        $script:SourceDir = $candidateB
    } else {
        Fail 'Nenhuma pasta .openclaw foi encontrada no repositório.'
    }

    Success "Pacote RobotizAI localizado em: $script:SourceDir"
}

function Install-BasePackagesWindows {
    Install-PackageIfMissing -CommandName 'git' -DisplayName 'Git' -WingetIds @('Git.Git') -ChocoPackages @('git') -ScoopPackages @('git')

    if (-not (Test-Command 'python') -and -not (Test-Command 'py')) {
        Info 'Instalando Python 3...'
        $installed = $false
        $installed = Install-WithWinget -Ids @('Python.Python.3.13', 'Python.Python.3.12', 'Python.Python.3.11') -DisplayName 'Python 3'
        if (-not $installed) { $installed = Install-WithChoco -Packages @('python') -DisplayName 'Python 3' }
        if (-not $installed) { $installed = Install-WithScoop -Packages @('python') -DisplayName 'Python 3' }
        if (-not $installed) {
            Fail 'Não foi possível instalar Python 3 automaticamente. Instale manualmente e execute novamente.'
        }
        Refresh-Path
    }

    if (-not (Test-Command 'python') -and -not (Test-Command 'py')) {
        Fail 'Python 3 não foi encontrado após a instalação.'
    }

    Success 'Dependências base instaladas/verificadas.'
}

function Resolve-NpmCmd {
    Refresh-Path
    $cmd = Get-Command 'npm.cmd' -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $candidate = Join-Path ${env:ProgramFiles} 'nodejs\npm.cmd'
    if (Test-Path $candidate) { return $candidate }

    $candidateX86 = Join-Path ${env:ProgramFiles(x86)} 'nodejs\npm.cmd'
    if (Test-Path $candidateX86) { return $candidateX86 }

    return $null
}

function Install-OrUpgrade-NodeWindows {
    $currentMajor = Get-NodeMajor
    $npmCmd = Resolve-NpmCmd

    if ((Test-Command 'node') -and $npmCmd -and $currentMajor -ge 24) {
        Success ("Node {0} e npm {1} já atendem ao requisito mínimo; pulando reinstalação." -f (& node --version), (& $npmCmd --version))
        return
    }

    Info 'Instalando/atualizando Node.js 24+...'

    $installed = $false
    $installed = Install-WithWinget -Ids @('OpenJS.NodeJS.LTS', 'OpenJS.NodeJS') -DisplayName 'Node.js'
    if (-not $installed) { $installed = Install-WithChoco -Packages @('nodejs-lts', 'nodejs') -DisplayName 'Node.js' }
    if (-not $installed) { $installed = Install-WithScoop -Packages @('nodejs-lts', 'nodejs') -DisplayName 'Node.js' }
    if (-not $installed) {
        Fail 'Não foi possível instalar Node.js automaticamente. Instale manualmente e execute novamente.'
    }

    Refresh-Path
    $npmCmd = Resolve-NpmCmd

    if (-not (Test-Command 'node') -or -not $npmCmd) {
        Fail 'Node.js ou npm não foram encontrados após a instalação.'
    }

    if ((Get-NodeMajor) -lt 24) {
        Fail ('A versão instalada do Node ({0}) é inferior à 24.' -f (& node --version))
    }

    Success ("Node {0} e npm {1} instalados/verificados." -f (& node --version), (& $npmCmd --version))
}

function OpenClaw-IsOfficialCli {
    Refresh-Path

    $cmd = Get-Command 'openclaw.cmd' -ErrorAction SilentlyContinue
    if (-not $cmd) {
        $cmd = Get-Command 'openclaw' -ErrorAction SilentlyContinue
    }
    if (-not $cmd) { return $false }

    $resolved = $cmd.Source
    if ($resolved -like "$HOME\.openclaw*") { return $false }

    try {
        & $resolved --version | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Resolve-OpenClawCommand {
    Refresh-Path

    foreach ($name in @('openclaw.cmd', 'openclaw')) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) {
            return $cmd.Source
        }
    }

    $npmCmd = Resolve-NpmCmd
    if ($npmCmd) {
        $npmPrefix = (& $npmCmd prefix -g 2>$null)
        if ($npmPrefix) {
            foreach ($candidate in @(
                (Join-Path $npmPrefix 'openclaw.cmd'),
                (Join-Path $npmPrefix 'openclaw.ps1'),
                (Join-Path $npmPrefix 'openclaw')
            )) {
                if (Test-Path $candidate) {
                    return $candidate
                }
            }
        }
    }

    return $null
}

function Install-OfficialOpenClaw {
    if (OpenClaw-IsOfficialCli) {
        $script:OpenClawCmd = Resolve-OpenClawCommand
        Success "CLI oficial do OpenClaw já está instalada em: $script:OpenClawCmd; pulando reinstalação."
        try { & $script:OpenClawCmd --version | Out-Host } catch {}
        return
    }

    $npmCmd = Resolve-NpmCmd
    if (-not $npmCmd) {
        Fail 'npm.cmd não foi encontrado.'
    }

    Info 'Instalando OpenClaw oficial com npm install -g openclaw@latest...'

    try { & $npmCmd cache verify *> $null } catch {}

    $env:npm_config_loglevel = 'warn'
    $env:npm_config_fund = 'false'
    $env:npm_config_audit = 'false'
    if (-not $env:NODE_OPTIONS) {
        $env:NODE_OPTIONS = '--max-old-space-size=2048'
    }

    & $npmCmd install -g openclaw@latest --loglevel=warn --fund=false --audit=false
    if ($LASTEXITCODE -ne 0) {
        Fail 'Falha ao instalar o OpenClaw oficial com npm.'
    }

    $script:OpenClawCmd = Resolve-OpenClawCommand
    if (-not $script:OpenClawCmd) {
        Fail 'O comando openclaw não foi encontrado após a instalação oficial.'
    }

    Success "CLI oficial encontrada em: $script:OpenClawCmd"
    try { & $script:OpenClawCmd --version | Out-Host } catch {}
}

function Stage-PreviousInstall {
    if (Test-Path $script:DestDir) {
        Success "Instalação atual detectada em $script:DestDir; os arquivos serão substituídos individualmente sem apagar a pasta inteira."
    } else {
        Success "Nenhuma instalação anterior em $script:DestDir; a estrutura oficial será criada na próxima etapa."
    }
}

function Initialize-OfficialHome {
    if (Test-Path $script:DestDir) {
        Success 'A pasta ~/.openclaw já existe; pulando recriação oficial.'
        return
    }

    if (-not $script:OpenClawCmd) {
        $script:OpenClawCmd = Resolve-OpenClawCommand
    }
    if (-not $script:OpenClawCmd) {
        Fail 'O comando openclaw não foi encontrado antes do setup.'
    }

    Info 'Inicializando a pasta oficial ~/.openclaw com openclaw setup...'
    & $script:OpenClawCmd setup
    if ($LASTEXITCODE -ne 0) {
        Fail 'openclaw setup falhou ao inicializar a pasta oficial.'
    }

    if (-not (Test-Path $script:DestDir)) {
        Fail 'O OpenClaw oficial não criou a pasta ~/.openclaw.'
    }

    Success "Pasta oficial criada com sucesso em $script:DestDir"
}

function Replace-WithRobotizaiBundle {
    if (-not (Test-Path $script:SourceDir)) { Fail 'A pasta de origem RobotizAI não existe.' }
    if (-not (Test-Path $script:DestDir)) { Fail 'A pasta de destino ~/.openclaw não existe.' }

    Info 'Substituindo os arquivos da ~/.openclaw pela versão RobotizAI do GitHub...'

    $robocopy = Get-Command 'robocopy.exe' -ErrorAction SilentlyContinue
    if ($robocopy) {
        & $robocopy.Source $script:SourceDir $script:DestDir /E /R:2 /W:1 /NFL /NDL /NJH /NJS /NC /NS /NP | Out-Null
        $code = $LASTEXITCODE
        if ($code -gt 7) {
            Fail "A atualização dos arquivos RobotizAI falhou (robocopy exit code $code)."
        }
    } else {
        $directories = Get-ChildItem -LiteralPath $script:SourceDir -Force -Recurse -Directory
        foreach ($dir in $directories) {
            $relative = $dir.FullName.Substring($script:SourceDir.Length).TrimStart('\\')
            $targetDir = Join-Path $script:DestDir $relative
            if ((Test-Path $targetDir) -and -not (Test-Path $targetDir -PathType Container)) {
                Remove-Item -LiteralPath $targetDir -Recurse -Force
            }
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }
        }

        $files = Get-ChildItem -LiteralPath $script:SourceDir -Force -Recurse -File
        foreach ($file in $files) {
            $relative = $file.FullName.Substring($script:SourceDir.Length).TrimStart('\\')
            $targetFile = Join-Path $script:DestDir $relative
            $targetParent = Split-Path -Parent $targetFile
            if (-not (Test-Path $targetParent)) {
                New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
            }
            if ((Test-Path $targetFile) -and (Test-Path $targetFile -PathType Container)) {
                Remove-Item -LiteralPath $targetFile -Recurse -Force
            }
            Copy-Item -LiteralPath $file.FullName -Destination $targetFile -Force
        }
    }

    Success "Arquivos RobotizAI copiados individualmente para $script:DestDir"
}

function Gateway-IsRunning {
    if (-not $script:OpenClawCmd) { return $false }
    $tmp = Join-Path $env:TEMP 'openclaw-gateway-status.log'
    try {
        & $script:OpenClawCmd gateway status *> $tmp
        if ($LASTEXITCODE -ne 0) { return $false }
        $content = Get-Content -LiteralPath $tmp -Raw -ErrorAction SilentlyContinue
        return $content -match '(?i)running|online|connected|ok|healthy|ativo'
    } catch {
        return $false
    }
}

function Restart-Gateway {
    if (-not $script:OpenClawCmd) {
        $script:OpenClawCmd = Resolve-OpenClawCommand
    }
    if (-not $script:OpenClawCmd) {
        Fail 'O comando openclaw não foi encontrado antes de reiniciar o gateway.'
    }

    if (Gateway-IsRunning) {
        Info 'Gateway já está ativo; reiniciando para aplicar a versão RobotizAI...'
    } else {
        Info 'Gateway não está ativo; iniciando/reiniciando...'
    }

    & $script:OpenClawCmd gateway restart
    if ($LASTEXITCODE -ne 0) {
        Fail 'Falha ao reiniciar o gateway do OpenClaw.'
    }

    Success 'Gateway reiniciado.'
}

function Onboard-AlreadyDone {
    return (Test-Path $script:DestDir) -and (Test-Path (Join-Path $script:DestDir 'openclaw.json'))
}

function Run-Onboard {
    if (-not $script:OpenClawCmd) {
        $script:OpenClawCmd = Resolve-OpenClawCommand
    }
    if (-not $script:OpenClawCmd) {
        Fail 'O comando openclaw não foi encontrado antes do onboard.'
    }

    if (Onboard-AlreadyDone) {
        Success 'Estrutura principal do OpenClaw já existe; pulando nova execução do onboard.'
        return
    }

    Info 'Executando openclaw onboard automaticamente...'
    & $script:OpenClawCmd onboard --install-daemon
    if ($LASTEXITCODE -ne 0) {
        Fail 'O onboarding do OpenClaw falhou.'
    }
    Success 'Onboarding concluído.'
}

function Dashboard-AlreadyRunning {
    try {
        $processes = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
            $_.CommandLine -and $_.CommandLine -match 'openclaw(\.cmd)?\s+dashboard'
        }
        return $null -ne $processes
    } catch {
        return $false
    }
}

function Open-Dashboard {
    if (-not $script:OpenClawCmd) {
        $script:OpenClawCmd = Resolve-OpenClawCommand
    }
    if (-not $script:OpenClawCmd) {
        Fail 'O comando openclaw não foi encontrado antes de abrir o dashboard.'
    }

    Info 'Abrindo o dashboard do OpenClaw...'

    if (Dashboard-AlreadyRunning) {
        Success 'Dashboard já está em execução; pulando nova abertura.'
        return
    }

    Start-Process -FilePath 'powershell.exe' -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-Command',
        "& '$($script:OpenClawCmd.Replace("'", "''"))' dashboard"
    ) | Out-Null

    Start-Sleep -Seconds 8
    Success 'Dashboard acionado.'
}

try {
    Show-Banner

    Next-Step 'Instalando dependências base (curl, git, python3, venv)'
    Install-BasePackagesWindows

    Next-Step 'Baixando o repositório RobotizAI'
    Prepare-Source

    Next-Step 'Garantindo Node.js 24 ou superior e npm'
    Install-OrUpgrade-NodeWindows

    Next-Step 'Preparando uma instalação oficial limpa do OpenClaw'
    Stage-PreviousInstall

    Next-Step 'Instalando a CLI oficial do OpenClaw via npm'
    Install-OfficialOpenClaw

    Next-Step 'Criando a ~/.openclaw oficial do OpenClaw'
    Initialize-OfficialHome

    Next-Step 'Substituindo a ~/.openclaw oficial pela versão RobotizAI'
    Replace-WithRobotizaiBundle

    Next-Step 'Reiniciando o gateway do OpenClaw'
    Restart-Gateway

    Next-Step 'Executando openclaw onboard automaticamente'
    Run-Onboard

    Next-Step 'Abrindo o dashboard do OpenClaw'
    Open-Dashboard

    Next-Step 'Concluindo'

    if (Test-Path $script:TmpDir) {
        Remove-Item -LiteralPath $script:TmpDir -Recurse -Force
    }

    $script:InstallSucceeded = $true

    Write-Host ''
    Success 'Instalação concluída com sucesso!'
    Write-Host ''
    Write-Host ("OpenClaw oficial instalado: {0}" -f $script:OpenClawCmd)
    try {
        Write-Host ("Versão do OpenClaw: {0}" -f (& $script:OpenClawCmd --version))
    } catch {
    }
    Write-Host ''
    Write-Host '🤖 Comandos úteis:'
    Write-Host '  openclaw onboard -> Configurações iniciais do openclaw'
    Write-Host '  openclaw gateway stop -> Finaliza o openclaw'
    Write-Host '  openclaw gateway start -> Inicia o openclaw'
    Write-Host '  openclaw gateway restart -> Reinicia o openclaw'
    Write-Host '  openclaw dashboard -> Abre o openclaw no navegador padrão'
    Write-Host ''
    Write-Host '👉 Próximo comando, digite:'
    Write-Host '  openclaw onboard'
    Write-Host ''
    Write-Host '👉 Depois que concluir as configurações inicias (com openclaw onboard) atualize a página do Openclaw (apertando Ctrl + F5) ou digite o comando:'
    Write-Host '  openclaw dashboard'
}
catch {
    Write-Host ''
    Warn-Message 'A instalação falhou.'
    Write-Error $_.Exception.Message
    exit 1
}
finally {
    if (-not $script:InstallSucceeded) {
        if (Test-Path $script:TmpDir) {
            try {
                Remove-Item -LiteralPath $script:TmpDir -Recurse -Force
            } catch {
            }
        }
    }
}
