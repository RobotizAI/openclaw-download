Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force | Out-Null
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
    Write-Host '     OpenClaw RobotizAI Installer v79.5 - Windows'
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
        if ($null -eq $segment) {
            continue
        }

        foreach ($item in ($segment -split ';')) {
            if (-not [string]::IsNullOrWhiteSpace($item)) {
                $parts.Add($item.Trim())
            }
        }
    }

    $env:Path = ($parts | Select-Object -Unique) -join ';'
}

function Test-Command {
    param([string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-NodeMajor {
    if (Test-Command 'node') {
        $version = (& node --version 2>$null)
        if ($version -match '^v(\d+)') {
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

function Assert-WingetAvailable {
    if (-not (Test-Command 'winget')) {
        Fail 'winget nao foi encontrado. No Windows, este instalador requer o Windows Package Manager para instalar dependencias automaticamente.'
    }
}

function Resolve-WingetPackageId {
    param([string[]]$Candidates)

    foreach ($candidate in $Candidates) {
        & winget show --id $candidate -e --source winget --accept-source-agreements | Out-Null
        if ($LASTEXITCODE -eq 0) {
            return $candidate
        }
    }

    return $null
}

function Install-WingetPackage {
    param(
        [string]$PackageId,
        [switch]$TryUpgradeFirst
    )

    if ($TryUpgradeFirst) {
        $upgradeArgs = @(
            'upgrade', '--id', $PackageId, '-e', '--source', 'winget',
            '--accept-package-agreements', '--accept-source-agreements', '--silent'
        )
        if (Test-IsAdministrator) {
            $upgradeArgs += @('--scope', 'machine')
        }

        & winget @upgradeArgs
        if ($LASTEXITCODE -eq 0) {
            Refresh-Path
            return $true
        }
    }

    $installArgs = @(
        'install', '--id', $PackageId, '-e', '--source', 'winget',
        '--accept-package-agreements', '--accept-source-agreements', '--silent'
    )
    if (Test-IsAdministrator) {
        $installArgs += @('--scope', 'machine')
    }

    & winget @installArgs
    Refresh-Path
    return ($LASTEXITCODE -eq 0)
}

function Install-WingetPackageIfMissing {
    param(
        [string]$CommandName,
        [string[]]$PackageCandidates,
        [string]$DisplayName
    )

    if (Test-Command $CommandName) {
        return
    }

    Assert-WingetAvailable
    $packageId = Resolve-WingetPackageId -Candidates $PackageCandidates
    if (-not $packageId) {
        Fail "Nao foi possivel localizar um pacote winget valido para $DisplayName."
    }

    Info "Instalando $DisplayName via winget ($packageId)..."
    if (-not (Install-WingetPackage -PackageId $packageId)) {
        Fail "Falha ao instalar $DisplayName via winget."
    }

    if (-not (Test-Command $CommandName)) {
        Fail "$DisplayName nao foi encontrado apos a instalacao."
    }
}

function Prepare-Source {
    if (Test-Path $script:TmpDir) {
        Remove-Item -LiteralPath $script:TmpDir -Recurse -Force
    }

    & git clone --depth 1 $script:RepoUrl $script:TmpDir
    if ($LASTEXITCODE -ne 0) {
        Fail 'Falha ao clonar o repositorio RobotizAI.'
    }

    $candidateA = Join-Path $script:TmpDir '.openclaw'
    $candidateB = Join-Path $script:TmpDir 'openclaw'

    if (Test-Path $candidateA) {
        $script:SourceDir = $candidateA
    }
    elseif (Test-Path $candidateB) {
        $script:SourceDir = $candidateB
    }
    else {
        Fail 'Nenhuma pasta .openclaw foi encontrada no repositorio.'
    }

    Success "Pacote RobotizAI localizado em: $script:SourceDir"
}

function Install-BasePackagesWindows {
    Install-WingetPackageIfMissing -CommandName 'git' -PackageCandidates @('Git.Git') -DisplayName 'Git'

    if (-not (Test-Command 'python') -and -not (Test-Command 'py')) {
        Assert-WingetAvailable
        $pythonPackageId = Resolve-WingetPackageId -Candidates @('Python.Python.3.13', 'Python.Python.3.12', 'Python.Python.3.11')
        if (-not $pythonPackageId) {
            Fail 'Nao foi possivel localizar um pacote winget valido para Python 3.'
        }

        Info "Instalando Python 3 via winget ($pythonPackageId)..."
        if (-not (Install-WingetPackage -PackageId $pythonPackageId)) {
            Fail 'Falha ao instalar Python 3 via winget.'
        }

        if (-not (Test-Command 'python') -and -not (Test-Command 'py')) {
            Fail 'Python 3 nao foi encontrado apos a instalacao.'
        }
    }

    Success 'Dependencias base instaladas/verificadas.'
}

function Install-OrUpgrade-NodeWindows {
    $currentMajor = Get-NodeMajor

    if ((Test-Command 'node') -and (Test-Command 'npm.cmd') -and $currentMajor -ge 24) {
        if ($currentMajor -ge 25) {
            Warn-Message ("Node {0} detectado. O OpenClaw recomenda Node 24 no Windows; continuando com a versao atual." -f (& node --version))
        }
        Success ("Node {0} e npm {1} ja atendem ao requisito minimo; pulando reinstalacao." -f (& node --version), (& npm.cmd --version))
        return
    }

    Info 'Garantindo Node.js 24 LTS no Windows...'

    $nodeReady = $false

    if (Test-Command 'winget') {
        $packageId = Resolve-WingetPackageId -Candidates @('OpenJS.NodeJS.LTS')
        if ($packageId) {
            Info "Tentando instalar/atualizar Node.js via winget ($packageId)..."
            $nodeReady = Install-WingetPackage -PackageId $packageId -TryUpgradeFirst
        }
    }

    Refresh-Path

    if ((Get-NodeMajor) -lt 24 -and (Test-Command 'choco')) {
        Info 'Tentando instalar/atualizar Node.js 24 LTS via Chocolatey...'
        try {
            if (Test-Command 'node') {
                & choco upgrade nodejs-lts -y | Out-Host
            } else {
                & choco install nodejs-lts -y | Out-Host
            }
            Refresh-Path
            $nodeReady = $true
        } catch {
        }
    }

    if ((Get-NodeMajor) -lt 24 -and (Test-Command 'scoop')) {
        Info 'Tentando instalar/atualizar Node.js 24 LTS via Scoop...'
        try {
            if (Test-Path (Join-Path $env:USERPROFILE 'scoop\apps\nodejs-lts')) {
                & scoop update nodejs-lts | Out-Host
            } else {
                & scoop install nodejs-lts | Out-Host
            }
            Refresh-Path
            $nodeReady = $true
        } catch {
        }
    }

    if (-not (Test-Command 'node') -or -not (Test-Command 'npm.cmd')) {
        Fail 'Node.js ou npm nao foram encontrados apos a instalacao.'
    }

    $currentMajor = Get-NodeMajor
    if ($currentMajor -lt 24) {
        Fail ("Node.js 24 ou superior e obrigatorio neste instalador para Windows. Versao atual detectada: {0}" -f (& node --version))
    }

    if ($currentMajor -ge 25) {
        Warn-Message ("Node {0} detectado. O OpenClaw recomenda Node 24 no Windows; continuando com a versao atual." -f (& node --version))
    }

    Success ("Node {0} e npm {1} instalados/verificados." -f (& node --version), (& npm.cmd --version))
}

function Resolve-NpmCmd {
    Refresh-Path

    $cmd = Get-Command 'npm.cmd' -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    $candidate = Join-Path $env:ProgramFiles 'nodejs\npm.cmd'
    if (Test-Path $candidate) {
        return $candidate
    }

    $candidateX86 = Join-Path ${env:ProgramFiles(x86)} 'nodejs\npm.cmd'
    if ($candidateX86 -and (Test-Path $candidateX86)) {
        return $candidateX86
    }

    return $null
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
        try {
            $npmPrefix = (& $npmCmd prefix -g 2>$null)
            if ($npmPrefix) {
                foreach ($candidate in @(
                    (Join-Path $npmPrefix 'openclaw.cmd'),
                    (Join-Path $npmPrefix 'openclaw')
                )) {
                    if (Test-Path $candidate) {
                        return $candidate
                    }
                }
            }
        } catch {
        }
    }

    return $null
}

function OpenClaw-IsOfficialCli {
    $resolved = Resolve-OpenClawCommand
    if (-not $resolved) {
        return $false
    }

    if ($resolved -like "$HOME\.openclaw*") {
        return $false
    }

    try {
        & $resolved --version | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Install-OfficialOpenClaw {
    if (OpenClaw-IsOfficialCli) {
        $script:OpenClawCmd = Resolve-OpenClawCommand
        Success "CLI oficial do OpenClaw ja esta instalada em: $script:OpenClawCmd; pulando reinstalacao."
        try {
            & $script:OpenClawCmd --version | Out-Host
        } catch {
        }
        return
    }

    $npmCmd = Resolve-NpmCmd
    if (-not $npmCmd) {
        Fail 'npm.cmd nao foi encontrado apos a instalacao do Node.js.'
    }

    Info 'Instalando OpenClaw oficial com npm install -g openclaw@latest...'

    try {
        & $npmCmd cache verify | Out-Null
    } catch {
    }

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
        Fail 'O comando openclaw nao foi encontrado apos a instalacao oficial.'
    }

    if ($script:OpenClawCmd -like "$HOME\.openclaw*") {
        Fail 'O comando openclaw ainda esta apontando para a instalacao antiga em ~/.openclaw.'
    }

    Success "CLI oficial encontrada em: $script:OpenClawCmd"
    try {
        & $script:OpenClawCmd --version | Out-Host
    } catch {
    }
}

function Stage-PreviousInstall {
    if (Test-Path $script:DestDir) {
        Success "Instalacao atual detectada em $script:DestDir; os arquivos serao substituidos individualmente sem apagar a pasta inteira."
    }
    else {
        Success "Nenhuma instalacao anterior em $script:DestDir; a estrutura oficial sera criada na proxima etapa."
    }
}

function Initialize-OfficialHome {
    if (Test-Path $script:DestDir) {
        Success 'A pasta ~/.openclaw ja existe; pulando recriacao oficial.'
        return
    }

    if (-not $script:OpenClawCmd) {
        $script:OpenClawCmd = Resolve-OpenClawCommand
    }

    Info 'Inicializando a pasta oficial ~/.openclaw com openclaw setup...'
    & $script:OpenClawCmd setup
    if ($LASTEXITCODE -ne 0) {
        Fail 'openclaw setup falhou ao inicializar a pasta oficial.'
    }

    if (-not (Test-Path $script:DestDir)) {
        Fail 'O OpenClaw oficial nao criou a pasta ~/.openclaw.'
    }

    Success "Pasta oficial criada com sucesso em $script:DestDir"
}

function Should-SkipSourceRelativePath {
    param([string]$RelativePath)

    $rel = ($RelativePath -replace '/', '\').TrimStart('\')
    $skipPrefixes = @(
        'openclaw.json',
        'browser',
        'completions',
        'canvas',
        'devices',
        'exec-approvals.json',
        'update-check.json',
        'cron\runs'
    )

    foreach ($prefix in $skipPrefixes) {
        if ($rel -ieq $prefix -or $rel -like ($prefix + '\*')) {
            return $true
        }
    }

    return $false
}

function Replace-WithRobotizaiBundle {
    if (-not (Test-Path $script:SourceDir)) {
        Fail 'A pasta de origem RobotizAI nao existe.'
    }

    if (-not (Test-Path $script:DestDir)) {
        Fail 'A pasta de destino ~/.openclaw nao existe.'
    }

    Info 'Substituindo os arquivos da ~/.openclaw pela versao RobotizAI do GitHub...'

    $items = Get-ChildItem -LiteralPath $script:SourceDir -Force -Recurse

    foreach ($item in $items) {
        $relativePath = $item.FullName.Substring($script:SourceDir.Length).TrimStart('\')
        if ([string]::IsNullOrWhiteSpace($relativePath)) {
            continue
        }

        if (Should-SkipSourceRelativePath -RelativePath $relativePath) {
            continue
        }

        $targetPath = Join-Path $script:DestDir $relativePath

        if ($item.PSIsContainer) {
            if ((Test-Path $targetPath) -and (-not (Get-Item -LiteralPath $targetPath).PSIsContainer)) {
                Remove-Item -LiteralPath $targetPath -Recurse -Force
            }
            New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
            continue
        }

        $targetParent = Split-Path -Parent $targetPath
        if (-not [string]::IsNullOrWhiteSpace($targetParent)) {
            New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
        }

        if ((Test-Path $targetPath) -and (Get-Item -LiteralPath $targetPath).PSIsContainer) {
            Remove-Item -LiteralPath $targetPath -Recurse -Force
        }

        Copy-Item -LiteralPath $item.FullName -Destination $targetPath -Force
    }

    if (-not (Test-Path $script:DestDir)) {
        Fail 'A atualizacao dos arquivos RobotizAI falhou.'
    }

    Success "Arquivos RobotizAI copiados individualmente para $script:DestDir"
}

function Get-GatewayStatusText {
    if (-not $script:OpenClawCmd) {
        return ''
    }

    try {
        $jsonOutput = & $script:OpenClawCmd gateway status --json 2>&1 | Out-String
        if (-not [string]::IsNullOrWhiteSpace($jsonOutput)) {
            return $jsonOutput.Trim()
        }
    } catch {
    }

    try {
        $textOutput = & $script:OpenClawCmd gateway status 2>&1 | Out-String
        if (-not [string]::IsNullOrWhiteSpace($textOutput)) {
            return $textOutput.Trim()
        }
    } catch {
    }

    return ''
}

function Gateway-IsRunning {
    $statusText = Get-GatewayStatusText
    if ([string]::IsNullOrWhiteSpace($statusText)) {
        return $false
    }

    if ($statusText -match '"(running|online|connected|healthy)"\s*:\s*true') {
        return $true
    }

    if ($statusText -match '"status"\s*:\s*"(running|online|healthy|ok)"') {
        return $true
    }

    if ($statusText -match '(?i)\brunning\b|\bonline\b|\bconnected\b|\bhealthy\b|\bok\b|\bativo\b') {
        return $true
    }

    return $false
}

function Restart-Gateway {
    if (-not $script:OpenClawCmd) {
        $script:OpenClawCmd = Resolve-OpenClawCommand
    }

    if (Gateway-IsRunning) {
        Info 'Gateway ja esta ativo; reiniciando para aplicar a versao RobotizAI...'
    }
    else {
        Info 'Gateway nao esta ativo; iniciando/reiniciando...'
    }

    try {
        & $script:OpenClawCmd gateway restart | Out-Host
    } catch {
    }

    Start-Sleep -Seconds 3

    if (Gateway-IsRunning) {
        Success 'Gateway reiniciado.'
        return
    }

    Warn-Message 'Gateway nao ficou ativo apos o restart. Tentando instalar/atualizar o servico...'

    try {
        & $script:OpenClawCmd gateway install --force | Out-Host
    } catch {
    }

    Start-Sleep -Seconds 2

    try {
        & $script:OpenClawCmd gateway restart | Out-Host
    } catch {
    }

    Start-Sleep -Seconds 3

    if (Gateway-IsRunning) {
        Success 'Gateway reiniciado.'
    }
    else {
        Warn-Message 'Gateway ainda nao esta ativo. No Windows nativo isso pode exigir PowerShell como Administrador ou uso de openclaw gateway run.'
    }
}

function Onboard-AlreadyDone {
    return (Test-Path (Join-Path $script:DestDir 'openclaw.json'))
}

function Run-Onboard {
    if (Onboard-AlreadyDone) {
        Success 'Estrutura principal do OpenClaw ja existe; pulando nova execucao do onboard.'
        return
    }

    if (-not $script:OpenClawCmd) {
        $script:OpenClawCmd = Resolve-OpenClawCommand
    }

    Info 'Executando openclaw onboard automaticamente...'
    & $script:OpenClawCmd onboard --install-daemon
    if ($LASTEXITCODE -ne 0) {
        Fail 'O onboarding do OpenClaw falhou.'
    }

    Success 'Onboarding concluido.'
}

function Dashboard-AlreadyRunning {
    try {
        $matches = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
            $_.CommandLine -and $_.CommandLine -match 'openclaw(\.cmd)?\s+dashboard'
        }
        return ($matches | Measure-Object).Count -gt 0
    } catch {
        return $false
    }
}

function Get-DashboardUrl {
    $dashboardHost = '127.0.0.1'
    $port = '18789'
    $configPath = Join-Path $script:DestDir 'openclaw.json'

    if (Test-Path $configPath) {
        try {
            $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json

            if ($config.gateway) {
                if ($config.gateway.port) {
                    $port = [string]$config.gateway.port
                }

                if ($config.gateway.bind) {
                    $bind = [string]$config.gateway.bind

                    if ($bind -match '^(loopback|localhost|127\.0\.0\.1)$') {
                        $dashboardHost = '127.0.0.1'
                    }
                    elseif ($bind -notmatch '^(0\.0\.0\.0|\*|all)$') {
                        $dashboardHost = $bind
                    }
                }
            }
        } catch {
        }
    }

    return ("http://{0}:{1}/" -f $dashboardHost, $port)
}

function Open-Dashboard {
    Info 'Abrindo o dashboard do OpenClaw...'

    $dashboardUrl = Get-DashboardUrl

    if (-not (Gateway-IsRunning)) {
        Warn-Message ("Gateway nao esta ativo. O dashboard nao pode ser aberto em {0}" -f $dashboardUrl)
        return
    }

    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri $dashboardUrl -Method Get -TimeoutSec 10
        if (-not $response -or -not $response.StatusCode -or $response.StatusCode -lt 200 -or $response.StatusCode -ge 400) {
            Warn-Message ("O dashboard nao respondeu corretamente em {0}" -f $dashboardUrl)
            return
        }
    }
    catch {
        Warn-Message ("O dashboard nao respondeu corretamente em {0}" -f $dashboardUrl)
        return
    }

    Start-Process $dashboardUrl | Out-Null
    Success ("Dashboard aberto no navegador padrao: {0}" -f $dashboardUrl)
}

try {
    Show-Banner

    Next-Step 'Instalando dependencias base (curl, git, python3, venv)'
    Install-BasePackagesWindows

    Next-Step 'Baixando o repositorio RobotizAI'
    Prepare-Source

    Next-Step 'Garantindo Node.js 24 ou superior e npm'
    Install-OrUpgrade-NodeWindows

    Next-Step 'Preparando uma instalacao oficial limpa do OpenClaw'
    Stage-PreviousInstall

    Next-Step 'Instalando a CLI oficial do OpenClaw via npm'
    Install-OfficialOpenClaw

    Next-Step 'Criando a ~/.openclaw oficial do OpenClaw'
    Initialize-OfficialHome

    Next-Step 'Substituindo a ~/.openclaw oficial pela versao RobotizAI'
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
    Success 'Instalacao concluida com sucesso!'
    Write-Host ''
    Write-Host ("OpenClaw oficial instalado: {0}" -f $script:OpenClawCmd)

    try {
        Write-Host ("Versao do OpenClaw: {0}" -f (& $script:OpenClawCmd --version))
    } catch {
    }

    Write-Host ''
    Write-Host '*Comandos uteis:'
    Write-Host '  openclaw onboard -> Configuracoes iniciais do openclaw'
    Write-Host '  openclaw gateway stop -> Finaliza o openclaw'
    Write-Host '  openclaw gateway start -> Inicia o openclaw'
    Write-Host '  openclaw gateway restart -> Reinicia o openclaw'
    Write-Host '  openclaw dashboard -> Abre o openclaw no navegador padrao'
    Write-Host ''
    Write-Host '-> Proximo comando, digite:'
    Write-Host '  openclaw onboard'
    Write-Host ''
    Write-Host '-> Depois que concluir as configuracoes iniciais (com openclaw onboard) atualize a pagina do Openclaw (apertando Ctrl + F5) ou digite o comando:'
    Write-Host '  openclaw dashboard'
}
catch {
    Write-Host ''
    Warn-Message 'A instalacao falhou.'
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
