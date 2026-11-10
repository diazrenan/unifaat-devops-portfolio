# Blue/Green Deployment Script (PowerShell)
# Automatiza o processo de deploy de uma cor para outra

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("deploy", "status", "rollback", "help")]
    [string]$Command = "deploy"
)

# Configuration
$TerraformDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) ".." "terraform"
$HealthCheckTimeout = 300  # 5 minutes
$HealthCheckInterval = 10  # 10 seconds

# Functions
function Write-Header {
    param([string]$Message)
    Write-Host "════════════════════════════════════════" -ForegroundColor Blue
    Write-Host $Message -ForegroundColor Blue
    Write-Host "════════════════════════════════════════" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Cyan
}

# Check prerequisites
function Test-Prerequisites {
    Write-Header "Verificando pré-requisitos"

    # Check Terraform
    if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
        Write-Error-Custom "Terraform não encontrado. Instale antes de continuar."
        exit 1
    }
    $TfVersion = terraform version -json | ConvertFrom-Json | Select-Object -ExpandProperty terraform_version
    Write-Success "Terraform: $TfVersion"

    # Check AWS CLI
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        Write-Error-Custom "AWS CLI não encontrado. Instale antes de continuar."
        exit 1
    }
    $AwsVersion = aws --version
    Write-Success "AWS CLI: $AwsVersion"

    # Check AWS credentials
    try {
        $null = aws sts get-caller-identity -ErrorAction Stop
        Write-Success "AWS credentials: OK"
    }
    catch {
        Write-Error-Custom "AWS credentials não configurados. Execute 'aws configure'"
        exit 1
    }
}

# Get outputs from Terraform
function Get-TerraformOutputs {
    Write-Header "Obtendo outputs do Terraform"

    Push-Location $TerraformDir

    try {
        $script:AlbDns = terraform output -raw alb_dns_name
        $script:BlueTg = terraform output -raw blue_tg_arn
        $script:GreenTg = terraform output -raw green_tg_arn
        $script:ListenerArn = terraform output -raw listener_arn
    }
    catch {
        Write-Error-Custom "Não foi possível obter outputs do Terraform"
        Write-Info "Execute 'terraform apply' no diretório terraform/ primeiro"
        Pop-Location
        exit 1
    }

    Pop-Location

    Write-Success "ALB DNS: $AlbDns"
    Write-Success "Blue TG: $($BlueTg.Split('/')[-1])"
    Write-Success "Green TG: $($GreenTg.Split('/')[-1])"
}

# Get current active color
function Get-ActiveColor {
    Write-Info "Identificando ambiente ativo..."

    $CurrentTg = aws elbv2 describe-listeners `
        --listener-arns $ListenerArn `
        --query 'Listeners[0].DefaultActions[0].TargetGroupArn' `
        --output text

    if ($CurrentTg -like "*blue*") {
        $script:ActiveColor = "blue"
        $script:StandbyColor = "green"
        $script:StandbyTg = $GreenTg
    }
    else {
        $script:ActiveColor = "green"
        $script:StandbyColor = "blue"
        $script:StandbyTg = $BlueTg
    }

    Write-Success "Ambiente ativo: $ActiveColor"
    Write-Success "Ambiente standby: $StandbyColor"
}

# Check health of target group
function Test-TargetHealth {
    param(
        [string]$TargetGroupArn,
        [string]$Color
    )

    Write-Info "Verificando health dos targets no $Color..."

    $HealthOutput = aws elbv2 describe-target-health `
        --target-group-arn $TargetGroupArn `
        --output json | ConvertFrom-Json

    $HealthyCount = ($HealthOutput.TargetHealthDescriptions | Where-Object { $_.TargetHealth.State -eq "healthy" }).Count
    $TotalCount = $HealthOutput.TargetHealthDescriptions.Count

    if ($HealthyCount -gt 0) {
        Write-Success "Health check ($Color): $HealthyCount/$TotalCount saudáveis"
        return $true
    }
    else {
        Write-Error-Custom "Health check ($Color): 0/$TotalCount saudáveis"
        return $false
    }
}

# Wait for health checks to pass
function Wait-HealthChecks {
    param(
        [string]$TargetGroupArn,
        [string]$Color,
        [int]$Timeout
    )

    Write-Header "Aguardando health checks do ambiente $Color"

    $StartTime = Get-Date
    $TimeoutSpan = New-TimeSpan -Seconds $Timeout

    while ($true) {
        if (Test-TargetHealth $TargetGroupArn $Color) {
            return $true
        }

        $Elapsed = (Get-Date) - $StartTime
        if ($Elapsed -gt $TimeoutSpan) {
            Write-Error-Custom "Health checks não passaram dentro de $Timeout segundos"
            return $false
        }

        Write-Info "Tentando novamente em $HealthCheckInterval segundos..."
        Start-Sleep -Seconds $HealthCheckInterval
    }
}

# Perform health check via HTTP
function Test-HttpHealth {
    Write-Header "Fazendo health check HTTP no ALB"

    $StartTime = Get-Date
    $TimeoutSpan = New-TimeSpan -Seconds $HealthCheckTimeout

    while ($true) {
        try {
            $Response = Invoke-WebRequest -Uri "http://$AlbDns/" -UseBasicParsing -ErrorAction Stop
            if ($Response.StatusCode -eq 200) {
                Write-Success "ALB respondendo corretamente"
                return $true
            }
        }
        catch {
            # Continue trying
        }

        $Elapsed = (Get-Date) - $StartTime
        if ($Elapsed -gt $TimeoutSpan) {
            Write-Error-Custom "ALB não respondeu dentro de $HealthCheckTimeout segundos"
            return $false
        }

        Write-Host "." -NoNewline -ForegroundColor Cyan
        Start-Sleep -Seconds 5
    }
}

# Switch traffic
function Invoke-TrafficSwitch {
    Write-Header "Redirecionando tráfego para $StandbyColor"

    Write-Info "Modificando listener..."
    aws elbv2 modify-listener `
        --listener-arn $ListenerArn `
        --default-actions Type=forward,TargetGroupArn=$StandbyTg `
        | Out-Null

    Start-Sleep -Seconds 5

    if (Test-HttpHealth) {
        Write-Success "Tráfego redirecionado com sucesso!"
        return $true
    }
    else {
        Write-Error-Custom "Health check falhou após redirect"
        Write-Warning-Custom "Revertendo para $ActiveColor..."

        if ($ActiveColor -eq "blue") {
            aws elbv2 modify-listener `
                --listener-arn $ListenerArn `
                --default-actions Type=forward,TargetGroupArn=$BlueTg `
                | Out-Null
        }
        else {
            aws elbv2 modify-listener `
                --listener-arn $ListenerArn `
                --default-actions Type=forward,TargetGroupArn=$GreenTg `
                | Out-Null
        }

        Write-Error-Custom "Rollback concluído"
        return $false
    }
}

# Display status
function Show-Status {
    Write-Header "Status Atual"

    $BlueHealth = (aws elbv2 describe-target-health `
        --target-group-arn $BlueTg `
        --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' `
        --output text)

    $GreenHealth = (aws elbv2 describe-target-health `
        --target-group-arn $GreenTg `
        --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' `
        --output text)

    Write-Host "ALB DNS: " -NoNewline -ForegroundColor White
    Write-Host $AlbDns -ForegroundColor Cyan
    Write-Host "Ambiente ativo: " -NoNewline -ForegroundColor White
    Write-Host $ActiveColor -ForegroundColor Green
    Write-Host "Ambiente standby: " -NoNewline -ForegroundColor White
    Write-Host $StandbyColor -ForegroundColor Yellow
    Write-Host "Blue targets saudáveis: " -NoNewline -ForegroundColor White
    Write-Host $BlueHealth -ForegroundColor Green
    Write-Host "Green targets saudáveis: " -NoNewline -ForegroundColor White
    Write-Host $GreenHealth -ForegroundColor Green
}

# Main deployment process
function Invoke-Deploy {
    Write-Header "Blue/Green Deployment Process"

    Test-Prerequisites
    Get-TerraformOutputs
    Get-ActiveColor

    Write-Info "Você está prestes a fazer deploy para: $StandbyColor"
    $Confirm = Read-Host "Deseja continuar? (s/n)"
    if ($Confirm -ne "s") {
        Write-Warning-Custom "Deploy cancelado"
        exit 0
    }

    if (-not (Wait-HealthChecks $StandbyTg $StandbyColor $HealthCheckTimeout)) {
        Write-Error-Custom "Não foi possível prosseguir - targets $StandbyColor não estão saudáveis"
        exit 1
    }

    if (-not (Invoke-TrafficSwitch)) {
        Write-Error-Custom "Falha ao redirecionar tráfego"
        exit 1
    }

    Show-Status

    Write-Success "Deploy concluído com sucesso!"
    Write-Info "Novo ambiente ativo: $StandbyColor"
}

# Show usage
function Show-Usage {
    Write-Host @"
Uso: $($MyInvocation.MyCommand.Name) [COMMAND]

Commands:
    deploy      Executar deploy de Blue/Green (padrão)
    status      Mostrar status atual
    rollback    Fazer rollback para ambiente anterior
    help        Mostrar esta mensagem

Exemplos:
    .$($MyInvocation.MyCommand.Name) deploy
    .$($MyInvocation.MyCommand.Name) status
    .$($MyInvocation.MyCommand.Name) rollback

"@
}

# Main
switch ($Command) {
    "deploy" {
        Invoke-Deploy
    }
    "status" {
        Test-Prerequisites
        Get-TerraformOutputs
        Get-ActiveColor
        Show-Status
    }
    "rollback" {
        Test-Prerequisites
        Get-TerraformOutputs
        Get-ActiveColor
        Write-Header "Fazendo rollback para $ActiveColor"
        Invoke-TrafficSwitch
    }
    "help" {
        Show-Usage
    }
    default {
        Write-Host "Comando desconhecido: $Command" -ForegroundColor Red
        Show-Usage
        exit 1
    }
}
