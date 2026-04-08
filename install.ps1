Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

try {
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force | Out-Null
} catch {
}

try {
    [Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    chcp 65001 > $null
} catch {
}

$script:RepoUrl = 'https://github.com/RobotizAI/openclaw-download.git'
$script:TmpDir = Join-Path $env:TEMP 'openclaw-install'
$script:DestDir = Join-Path $HOME '.openclaw'
$script:SourceDir = $null
$script:PreviousDestBackup = $null
$script:OpenClawCmd = $null
$script:NpmCmd = $null
$script:TotalSteps = 11
$script:CurrentStep = 0
$script:BarWidth = 34
$script:InstallSucceeded = $false

function Show-Banner {
    Write-Host ''
    Write-Host ' ===================================================='
    Write-Host '     OpenClaw RobotizAI Installer v75.2 - Windows'
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
    $parts = @()

    foreach ($segment in @($machinePath, $userPath, $env:Path)) {
        if ($null -eq $segment) {
            continue
        }
        foreach ($item in ($segment -split ';')) {
            if (-not [string]::IsNullOrWhiteSpace($item)) {
                $parts += $item.Trim()
            }
        }
    }

    $env:Path = ($parts | Select-Object -Unique) -join ';'
}

function Test-Command {
    param([string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-NpmCmd {
    Refresh-Path

    if ($script:NpmCmd -and (Test-Path $script:NpmCmd)) {
        return $script:NpmCmd
    }

    $cmd = Get-Command 'npm.cmd' -ErrorAction SilentlyContinue
    if ($cmd) {
        $script:NpmCmd = $cmd.Source
        return $script:NpmCmd
    }

    foreach ($candidate in @(
        (Join-Path $env:ProgramFiles 'nodejs\npm.cmd'),
        (Join-Path ${env:ProgramFiles(x86)} 'nodejs\npm.cmd')
    )) {
        if ($candidate -and (Test-Path $candidate)) {
            $script:NpmCmd = $candidate
            return $script:NpmCmd
        }
    }

    return $null
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

function Get-NpmVersion {
    $npmCmd = Get-NpmCmd
    if ($npmCmd) {
        return (& $npmCmd --version 2>$null)
    }
    return $null
}

function Test-IsAdministrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-WingetAvailable {
    if (-not (Test-Command 'winget')) {
        Fail 'winget não foi encontrado. No Windows, este instalador requer o Windows Package Manager para instalar dependências automaticamente.'
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
        Fail "Não foi possível localizar um pacote winget válido para $DisplayName."
    }

    Info "Instalando $DisplayName via winget ($packageId)..."

    $args = @(
        'install', '--id', $packageId, '-e', '--source', 'winget',
        '--accept-package-agreements', '--accept-source-agreements', '--silent'
    )

    if (Test-IsAdministrator) {
        $args += @('--scope', 'machine')
    }

    & winget @args
    if ($LASTEXITCODE -ne 0) {
        Fail "Falha ao instalar $DisplayName via winget."
    }
    Refresh-Path

    if (-not (Test-Command $CommandName)) {
        Fail "$DisplayName não foi encontrado após a instalação."
    }
}

function Prepare-Source {
    if (Test-Path $script:TmpDir) {
        Remove-Item -LiteralPath $script:TmpDir -Recurse -Force
    }

    & git clone --depth 1 $script:RepoUrl $script:TmpDir
    if ($LASTEXITCODE -ne 0) {
        Fail 'Falha ao clonar o repositório RobotizAI.'
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
        Fail 'Nenhuma pasta .openclaw foi encontrada no repositório.'
    }

    Success "Pacote RobotizAI localizado em: $script:SourceDir"
}

function Install-BasePackagesWindows {
    Install-WingetPackageIfMissing -CommandName 'git' -PackageCandidates @('Git.Git') -DisplayName 'Git'

    if (-not (Test-Command 'python') -and -not (Test-Command 'py')) {
        Assert-WingetAvailable
        $pythonPackageId = Resolve-WingetPackageId -Candidates @('Python.Python.3.13', 'Python.Python.3.12', 'Python.Python.3.11')
        if (-not $pythonPackageId) {
            Fail 'Não foi possível localizar um pacote winget válido para Python 3.'
        }

        Info "Instalando Python 3 via winget ($pythonPackageId)..."
        $args = @(
            'install', '--id', $pythonPackageId, '-e', '--source', 'winget',
            '--accept-package-agreements', '--accept-source-agreements', '--silent'
        )
        if (Test-IsAdministrator) {
            $args += @('--scope', 'machine')
        }
        & winget @args
        if ($LASTEXITCODE -ne 0) {
            Fail 'Falha ao instalar Python 3 via winget.'
        }
        Refresh-Path

        if (-not (Test-Command 'python') -and -not (Test-Command 'py')) {
            Fail 'Python 3 não foi encontrado após a instalação.'
        }
    }

    Success 'Dependências base instaladas/verificadas: git e python3.'
}

function Install-OrUpgrade-NodeWindows {
    $currentMajor = Get-NodeMajor
    $npmCmd = Get-NpmCmd

    if ((Test-Command 'node') -and $npmCmd -and $currentMajor -ge 24) {
        Success ("Node {0} e npm {1} já atendem ao requisito mínimo." -f (& node --version), (& $npmCmd --version))
        return
    }

    Assert-WingetAvailable

    $packageId = Resolve-WingetPackageId -Candidates @('OpenJS.NodeJS.LTS', 'OpenJS.NodeJS')
    if (-not $packageId) {
        Fail 'Não foi possível localizar um pacote winget válido para Node.js.'
    }

    Info "Instalando/atualizando Node.js via winget ($packageId)..."

    $args = @(
        'install', '--id', $packageId, '-e', '--source', 'winget',
        '--accept-package-agreements', '--accept-source-agreements', '--silent'
    )

    if (Test-IsAdministrator) {
        $args += @('--scope', 'machine')
    }

    & winget @args
    if ($LASTEXITCODE -ne 0) {
        $upgradeArgs = @(
            'upgrade', '--id', $packageId, '-e', '--source', 'winget',
            '--accept-package-agreements', '--accept-source-agreements', '--silent'
        )
        if (Test-IsAdministrator) {
            $upgradeArgs += @('--scope', 'machine')
        }
        & winget @upgradeArgs
    }

    Refresh-Path
    $npmCmd = Get-NpmCmd

    if (-not (Test-Command 'node') -or -not $npmCmd) {
        Fail 'Node.js ou npm não foram encontrados após a instalação.'
    }

    if ((Get-NodeMajor) -lt 24) {
        Fail ('A versão instalada do Node ({0}) é inferior à 24.' -f (& node --version))
    }

    Success ("Node {0} e npm {1} instalados." -f (& node --version), (& $npmCmd --version))
}

function Stage-PreviousInstall {
    if (Test-Path $script:DestDir) {
        $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $script:PreviousDestBackup = "${script:DestDir}.robotizai-pre-v75.2-$timestamp"
        Info "Movendo a instalação atual para backup temporário: $script:PreviousDestBackup"
        Move-Item -LiteralPath $script:DestDir -Destination $script:PreviousDestBackup
    }
}

function Resolve-OpenClawCommand {
    Refresh-Path

    $preferred = Get-Command 'openclaw.cmd' -ErrorAction SilentlyContinue
    if ($preferred) {
        return $preferred.Source
    }

    $npmCmd = Get-NpmCmd
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

    $fallback = Get-Command 'openclaw' -ErrorAction SilentlyContinue
    if ($fallback) {
        return $fallback.Source
    }

    return $null
}

function Install-OfficialOpenClaw {
    Info 'Instalando OpenClaw oficial com npm install -g openclaw@latest...'

    $npmCmd = Get-NpmCmd
    if (-not $npmCmd) {
        Fail 'npm.cmd não foi encontrado após a instalação do Node.js.'
    }

    try {
        & $npmCmd cache verify | Out-Null
    }
    catch {
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
        Fail 'O comando openclaw não foi encontrado após a instalação oficial.'
    }

    if ($script:OpenClawCmd -like "$HOME\.openclaw*") {
        Fail 'O comando openclaw ainda está apontando para a instalação antiga em ~/.openclaw.'
    }

    Success "CLI oficial encontrada em: $script:OpenClawCmd"

    try {
        & $script:OpenClawCmd --version | Out-Host
    }
    catch {
    }
}

function Initialize-OfficialHome {
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
    Info 'Substituindo ~/.openclaw pela versão RobotizAI do GitHub...'

    if (Test-Path $script:DestDir) {
        Remove-Item -LiteralPath $script:DestDir -Recurse -Force
    }

    Copy-Item -LiteralPath $script:SourceDir -Destination $script:DestDir -Recurse -Force

    if (-not (Test-Path $script:DestDir)) {
        Fail 'Falha ao copiar a pasta RobotizAI para ~/.openclaw.'
    }

    Success "Pasta RobotizAI copiada para $script:DestDir"
}

function Normalize-RobotizaiBundleForWindows {
    $configPath = Join-Path $script:DestDir 'openclaw.json'
    if (-not (Test-Path $configPath)) {
        Fail 'O bundle RobotizAI não contém ~/.openclaw/openclaw.json.'
    }

    Info 'Ajustando a configuração RobotizAI para Windows nativo...'

    $jsonText = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
    $config = $jsonText | ConvertFrom-Json

    $workspacePath = Join-Path $script:DestDir 'workspace'
    $extensionsRoot = Join-Path $script:DestDir 'extensions'

    if ($config.agents -and $config.agents.defaults) {
        $config.agents.defaults.workspace = $workspacePath
    }

    if ($config.agents -and $config.agents.list) {
        foreach ($agent in $config.agents.list) {
            if ($agent.PSObject.Properties.Name -contains 'workspace') {
                $agent.workspace = $workspacePath
            }
        }
    }

    if ($config.plugins -and $config.plugins.installs) {
        $remainingInstalls = [ordered]@{}
        foreach ($installEntry in $config.plugins.installs.PSObject.Properties) {
            $pluginId = $installEntry.Name
            $pluginInstall = $installEntry.Value

            if ($pluginId -eq 'openclaw-web-search') {
                continue
            }

            if ($pluginInstall -and ($pluginInstall.PSObject.Properties.Name -contains 'installPath')) {
                $pluginInstall.installPath = Join-Path $extensionsRoot $pluginId
            }

            $remainingInstalls[$pluginId] = $pluginInstall
        }
        $config.plugins.installs = [pscustomobject]$remainingInstalls
    }

    if ($config.plugins -and $config.plugins.allow) {
        $config.plugins.allow = @($config.plugins.allow | Where-Object { $_ -ne 'openclaw-web-search' })
    }

    if ($config.hooks -and $config.hooks.internal -and $config.hooks.internal.entries) {
        if ($config.hooks.internal.entries.PSObject.Properties.Name -contains 'session-memory') {
            if ($null -eq $config.hooks.internal.entries.'session-memory') {
                $config.hooks.internal.entries.'session-memory' = [pscustomobject]@{}
            }
            $config.hooks.internal.entries.'session-memory'.enabled = $false
        }
    }

    $jsonOut = $config | ConvertTo-Json -Depth 100 -Compress
    Set-Content -LiteralPath $configPath -Value $jsonOut -Encoding UTF8

    Success 'Configuração RobotizAI ajustada para Windows.'
}

function Repair-Configuration {
    Info 'Executando openclaw doctor para reparar/migrar a configuração...'

    try {
        & $script:OpenClawCmd doctor --non-interactive --fix | Out-Host
        if ($LASTEXITCODE -eq 0) {
            Success 'Configuração validada/reparada.'
            return
        }
    }
    catch {
    }

    Warn-Message 'openclaw doctor não conseguiu reparar tudo automaticamente. Continuando com a configuração atual.'
}

function Test-GatewayReady {
    try {
        $statusJson = & $script:OpenClawCmd gateway status --json 2>$null
        if ($LASTEXITCODE -eq 0 -and $statusJson) {
            $status = $statusJson | ConvertFrom-Json
            if ($status) {
                return $true
            }
        }
    }
    catch {
    }

    return $false
}

function Start-GatewayRunFallback {
    $gatewayLog = Join-Path $env:TEMP 'openclaw-gateway-run.log'
    $escapedOpenClaw = $script:OpenClawCmd.Replace("'", "''")
    $escapedLog = $gatewayLog.Replace("'", "''")

    Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-Command',
        "& '$escapedOpenClaw' gateway run *> '$escapedLog'"
    ) | Out-Null

    return $gatewayLog
}

function Restart-Gateway {
    Info 'Reiniciando o gateway do OpenClaw...'

    try {
        if (Test-IsAdministrator) {
            & $script:OpenClawCmd gateway install | Out-Host
        } else {
            Warn-Message 'PowerShell sem privilégios elevados: pulando gateway install e tentando iniciar o gateway no modo local do usuário.'
        }
    }
    catch {
    }

    try {
        & $script:OpenClawCmd gateway restart | Out-Host
    }
    catch {
    }

    for ($i = 0; $i -lt 4; $i++) {
        Start-Sleep -Seconds 2
        if (Test-GatewayReady) {
            Success 'Gateway instalado/reiniciado.'
            return
        }
    }

    Warn-Message 'Não foi possível confirmar o gateway gerenciado. Iniciando fallback com openclaw gateway run no perfil atual...'
    $gatewayLog = Start-GatewayRunFallback

    for ($i = 0; $i -lt 6; $i++) {
        Start-Sleep -Seconds 3
        if (Test-GatewayReady) {
            Success 'Gateway iniciado em modo local do usuário.'
            return
        }
    }

    Warn-Message "Não foi possível confirmar o gateway nesta etapa. Verifique o log em $gatewayLog"
}

function Run-Onboard {
    Info 'Executando openclaw onboard automaticamente...'

    $args = @(
        'onboard',
        '--non-interactive',
        '--mode', 'local',
        '--flow', 'quickstart',
        '--auth-choice', 'skip',
        '--accept-risk',
        '--skip-health',
        '--skip-channels',
        '--skip-skills',
        '--skip-search',
        '--skip-ui',
        '--no-install-daemon'
    )

    try {
        & $script:OpenClawCmd @args | Out-Host
        if ($LASTEXITCODE -eq 0) {
            Success 'Onboarding concluído.'
            return
        }
    }
    catch {
    }

    Warn-Message 'O onboarding completo não pôde ser concluído no Windows nativo. Continuando com a configuração RobotizAI já instalada.'
}

function Open-Dashboard {
    Info 'Abrindo o dashboard do OpenClaw...'

    Start-Process -FilePath 'powershell.exe' -ArgumentList @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-Command',
        "& '$($script:OpenClawCmd.Replace("'", "''"))' dashboard"
    ) | Out-Null

    Start-Sleep -Seconds 8
    Success 'Dashboard acionado.'
}

function Restore-PreviousInstallIfNeeded {
    if ($script:PreviousDestBackup -and (Test-Path $script:PreviousDestBackup)) {
        try {
            if (Test-Path $script:DestDir) {
                Remove-Item -LiteralPath $script:DestDir -Recurse -Force
            }
        }
        catch {
        }

        Move-Item -LiteralPath $script:PreviousDestBackup -Destination $script:DestDir -Force
        Warn-Message "A instalação anterior foi restaurada em $script:DestDir"
    }
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
    Normalize-RobotizaiBundleForWindows
    Repair-Configuration

    Next-Step 'Reiniciando o gateway do OpenClaw'
    Restart-Gateway

    Next-Step 'Executando openclaw onboard automaticamente'
    Run-Onboard

    Next-Step 'Abrindo o dashboard do OpenClaw'
    Open-Dashboard

    Next-Step 'Concluindo'

    if ($script:PreviousDestBackup -and (Test-Path $script:PreviousDestBackup)) {
        Remove-Item -LiteralPath $script:PreviousDestBackup -Recurse -Force
    }

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
    }
    catch {
    }

    Write-Host ''
    Write-Host 'Próximos comandos úteis:'
    Write-Host '  openclaw gateway status'
    Write-Host '  openclaw doctor'
    Write-Host '  openclaw dashboard'
}
catch {
    Write-Host ''
    Warn-Message 'A instalação falhou.'
    Restore-PreviousInstallIfNeeded
    Write-Error $_.Exception.Message
    exit 1
}
finally {
    if (-not $script:InstallSucceeded) {
        if (Test-Path $script:TmpDir) {
            try {
                Remove-Item -LiteralPath $script:TmpDir -Recurse -Force
            }
            catch {
            }
        }
    }
}
