# ===================================
# CallFlowEngine Deployment Script (Windows)
# ===================================
# Usage:
#   .\deploy-windows.ps1              - Initial deployment
#   .\deploy-windows.ps1 -Update      - Update existing deployment
#   .\deploy-windows.ps1 -Rollback    - Rollback to previous version
#   .\deploy-windows.ps1 -Status      - Check deployment status
# ===================================

param(
    [switch]$Update,
    [switch]$Rollback,
    [switch]$Status,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

# Project settings
$PROJECT_NAME = "call_flow_engine"
$COMPOSE_PROJECT_NAME = "callflow"
$BACKUP_DIR = ".\backups"
$LOG_FILE = ".\deploy.log"

# Default ports
$DEFAULT_APP_PORT = 4100
$DEFAULT_POSTGRES_PORT = 5433
$DEFAULT_NGINX_PORT = 8100

# ===================================
# Helper Functions
# ===================================

function Write-Log {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Host $logMessage -ForegroundColor Green
    Add-Content -Path $LOG_FILE -Value $logMessage
}

function Write-ErrorLog {
    param($Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    Add-Content -Path $LOG_FILE -Value "[ERROR] $Message"
}

function Write-WarnLog {
    param($Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
    Add-Content -Path $LOG_FILE -Value "[WARNING] $Message"
}

function Write-InfoLog {
    param($Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
    Add-Content -Path $LOG_FILE -Value "[INFO] $Message"
}

function Test-Command {
    param($Command)
    $exists = Get-Command $Command -ErrorAction SilentlyContinue
    if (-not $exists) {
        Write-ErrorLog "$Command is not installed. Please install it first."
        exit 1
    }
}

# ===================================
# Pre-flight Checks
# ===================================

function Test-PreFlight {
    Write-Log "Running pre-flight checks..."
    
    Test-Command "docker"
    Test-Command "docker-compose"
    
    # Check Docker daemon
    try {
        docker info | Out-Null
    } catch {
        Write-ErrorLog "Docker daemon is not running. Please start Docker Desktop."
        exit 1
    }
    
    Write-Log "Pre-flight checks passed ✓"
}

# ===================================
# Port Configuration
# ===================================

function Initialize-PortConfig {
    $portsFile = ".env.ports"
    
    if (Test-Path $portsFile) {
        Write-Log "Loading existing port configuration..."
        Get-Content $portsFile | ForEach-Object {
            if ($_ -match '^([^=]+)=(.*)$') {
                Set-Variable -Name $matches[1] -Value $matches[2] -Scope Script
            }
        }
        return
    }
    
    Write-Log "Configuring ports for deployment..."
    Write-Host ""
    Write-InfoLog "To avoid conflicts with other services, please configure custom ports."
    Write-Host ""
    
    # App port
    $appPortInput = Read-Host "Phoenix application port (default: $DEFAULT_APP_PORT)"
    $script:APP_PORT = if ($appPortInput) { $appPortInput } else { $DEFAULT_APP_PORT }
    
    # PostgreSQL port
    $postgresPortInput = Read-Host "PostgreSQL port (default: $DEFAULT_POSTGRES_PORT)"
    $script:POSTGRES_PORT = if ($postgresPortInput) { $postgresPortInput } else { $DEFAULT_POSTGRES_PORT }
    
    # Nginx port
    $nginxPortInput = Read-Host "Nginx HTTP port (default: $DEFAULT_NGINX_PORT, 0 to disable)"
    $script:NGINX_PORT = if ($nginxPortInput) { $nginxPortInput } else { $DEFAULT_NGINX_PORT }
    
    # Check if ports are available
    function Test-PortAvailable {
        param($Port)
        if ($Port -ne 0) {
            $connection = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
            if ($connection) {
                Write-ErrorLog "Port $Port is already in use!"
                return $false
            }
        }
        return $true
    }
    
    if (-not (Test-PortAvailable $APP_PORT)) {
        Write-ErrorLog "Please choose a different app port."
        exit 1
    }
    
    if (-not (Test-PortAvailable $POSTGRES_PORT)) {
        Write-ErrorLog "Please choose a different PostgreSQL port."
        exit 1
    }
    
    if (($NGINX_PORT -ne 0) -and -not (Test-PortAvailable $NGINX_PORT)) {
        Write-ErrorLog "Please choose a different Nginx port."
        exit 1
    }
    
    # Save configuration
    @"
# Port configuration for CallFlowEngine
APP_PORT=$APP_PORT
POSTGRES_PORT=$POSTGRES_PORT
NGINX_PORT=$NGINX_PORT
"@ | Out-File -FilePath $portsFile -Encoding UTF8
    
    Write-Log "Port configuration saved to $portsFile"
    Write-InfoLog "App will be accessible at: http://localhost:$APP_PORT"
    if ($NGINX_PORT -ne 0) {
        Write-InfoLog "Nginx will be accessible at: http://localhost:$NGINX_PORT"
    }
}

# ===================================
# Environment Configuration
# ===================================

function Initialize-Environment {
    $envFile = ".env"
    
    if (Test-Path $envFile) {
        Write-Log "Environment file already exists, skipping configuration."
        return
    }
    
    Write-Log "Configuring environment variables..."
    
    # Start with template
    if (Test-Path ".env.docker") {
        Copy-Item ".env.docker" $envFile
    } else {
        Write-ErrorLog ".env.docker template not found!"
        exit 1
    }
    
    # Update ports
    (Get-Content $envFile) -replace '4000', $APP_PORT | Set-Content $envFile
    
    # Generate SECRET_KEY_BASE
    Write-Log "Generating SECRET_KEY_BASE..."
    $secretKey = "CHANGE_ME_" + [System.Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
    (Get-Content $envFile) -replace 'SECRET_KEY_BASE=.*', "SECRET_KEY_BASE=$secretKey" | Set-Content $envFile
    
    Write-Host ""
    Write-InfoLog "Please configure the following settings (press Enter to keep default):"
    Write-Host ""
    
    # Asterisk ARI
    $ariUrl = Read-Host "Asterisk ARI URL (default: ws://asterisk:8088/ari/events)"
    if ($ariUrl) {
        (Get-Content $envFile) -replace 'ARI_URL=.*', "ARI_URL=$ariUrl" | Set-Content $envFile
    }
    
    $ariUser = Read-Host "Asterisk ARI Username (default: asterisk)"
    if ($ariUser) {
        (Get-Content $envFile) -replace 'ARI_USER=.*', "ARI_USER=$ariUser" | Set-Content $envFile
    }
    
    $ariPass = Read-Host "Asterisk ARI Password" -AsSecureString
    $ariPassPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($ariPass))
    if ($ariPassPlain) {
        (Get-Content $envFile) -replace 'ARI_PASSWORD=.*', "ARI_PASSWORD=$ariPassPlain" | Set-Content $envFile
    }
    
    # Bitrix24
    $bitrixUrl = Read-Host "Bitrix24 Webhook URL (optional)"
    if ($bitrixUrl) {
        (Get-Content $envFile) -replace 'BITRIX_WEBHOOK_URL=.*', "BITRIX_WEBHOOK_URL=$bitrixUrl" | Set-Content $envFile
    }
    
    Write-Log "Environment configuration completed ✓"
}

# ===================================
# Docker Compose Configuration
# ===================================

function Initialize-DockerCompose {
    Write-Log "Preparing docker-compose override..."
    
    $overrideContent = @"
version: '3.8'

services:
  postgres:
    ports:
      - "${POSTGRES_PORT}:5432"

  app:
    ports:
      - "${APP_PORT}:4000"
"@

    if ($NGINX_PORT -ne 0) {
        $overrideContent += @"


  nginx:
    image: nginx:alpine
    container_name: ${COMPOSE_PROJECT_NAME}_nginx
    ports:
      - "${NGINX_PORT}:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - app
    networks:
      - call_flow_network
    restart: unless-stopped
"@
    }
    
    $overrideContent | Out-File -FilePath "docker-compose.override.yml" -Encoding UTF8
    
    Write-Log "Docker Compose override created ✓"
}

# ===================================
# Backup Functions
# ===================================

function New-Backup {
    Write-Log "Creating backup..."
    
    if (-not (Test-Path $BACKUP_DIR)) {
        New-Item -ItemType Directory -Path $BACKUP_DIR | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = "$BACKUP_DIR\backup_$timestamp.zip"
    
    # Backup database
    if (docker ps --format "{{.Names}}" | Select-String "${COMPOSE_PROJECT_NAME}_postgres") {
        Write-Log "Backing up database..."
        docker exec "${COMPOSE_PROJECT_NAME}_postgres" pg_dump -U postgres call_flow_engine_dev | Out-File "$BACKUP_DIR\db_$timestamp.sql"
    }
    
    # Backup configuration files
    Compress-Archive -Path ".env", ".env.ports", "docker-compose.override.yml" -DestinationPath $backupFile -Force
    
    # Keep only last 5 backups
    Get-ChildItem "$BACKUP_DIR\backup_*.zip" | 
        Sort-Object LastWriteTime -Descending | 
        Select-Object -Skip 5 | 
        Remove-Item
    
    Write-Log "Backup created: $backupFile ✓"
    $backupFile | Out-File "$BACKUP_DIR\.last_backup" -Encoding UTF8
}

# ===================================
# Deployment Functions
# ===================================

function Start-InitialDeploy {
    Write-Log "Starting initial deployment of $PROJECT_NAME..."
    
    Test-PreFlight
    Initialize-PortConfig
    Initialize-Environment
    Initialize-DockerCompose
    
    Write-Log "Building and starting services..."
    docker-compose -p $COMPOSE_PROJECT_NAME build --no-cache
    docker-compose -p $COMPOSE_PROJECT_NAME up -d
    
    Write-Log "Waiting for services to be ready..."
    Start-Sleep -Seconds 10
    
    # Wait for health check
    $maxAttempts = 30
    $attempt = 0
    
    while ($attempt -lt $maxAttempts) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$APP_PORT/health" -UseBasicParsing
            if ($response.StatusCode -eq 200) {
                Write-Log "Service is healthy! ✓"
                break
            }
        } catch {
            Write-Host "." -NoNewline
        }
        $attempt++
        Start-Sleep -Seconds 2
    }
    Write-Host ""
    
    if ($attempt -eq $maxAttempts) {
        Write-ErrorLog "Service did not become healthy in time."
        exit 1
    }
    
    New-Backup
    
    Write-Log "═══════════════════════════════════════════════════════"
    Write-Log "Deployment completed successfully! 🎉"
    Write-Log "═══════════════════════════════════════════════════════"
    Write-InfoLog "Application URL: http://localhost:$APP_PORT"
    Write-InfoLog "Health check:    http://localhost:$APP_PORT/health"
    Write-InfoLog "API Stats:       http://localhost:$APP_PORT/api/stats"
    Write-Log "═══════════════════════════════════════════════════════"
}

function Start-UpdateDeploy {
    Write-Log "Starting update deployment..."
    
    if (-not (Test-Path ".env")) {
        Write-ErrorLog "No existing deployment found. Run '.\deploy-windows.ps1' first."
        exit 1
    }
    
    Test-PreFlight
    New-Backup
    
    Write-Log "Pulling latest changes..."
    if (Test-Path ".git") {
        git pull origin main
    }
    
    Write-Log "Rebuilding and restarting services..."
    docker-compose -p $COMPOSE_PROJECT_NAME build app
    docker-compose -p $COMPOSE_PROJECT_NAME up -d --force-recreate app
    
    Write-Log "Running database migrations..."
    docker-compose -p $COMPOSE_PROJECT_NAME exec -T app mix ecto.migrate
    
    Write-Log "Update completed successfully! ✓"
}

function Show-Status {
    Write-Log "Checking deployment status..."
    Write-Host ""
    
    docker-compose -p $COMPOSE_PROJECT_NAME ps
    
    if (Test-Path ".env.ports") {
        Initialize-PortConfig
        Write-InfoLog "Health check: http://localhost:$APP_PORT/health"
        try {
            $health = Invoke-RestMethod -Uri "http://localhost:$APP_PORT/health"
            $health | ConvertTo-Json
            Write-Log "Service is healthy ✓"
        } catch {
            Write-WarnLog "Service health check failed"
        }
    }
}

# ===================================
# Main Script
# ===================================

if ($Help) {
    Write-Host "CallFlowEngine Deployment Script (Windows)"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  .\deploy-windows.ps1              Initial deployment"
    Write-Host "  .\deploy-windows.ps1 -Update      Update existing deployment"
    Write-Host "  .\deploy-windows.ps1 -Rollback    Rollback to previous version"
    Write-Host "  .\deploy-windows.ps1 -Status      Check deployment status"
    Write-Host "  .\deploy-windows.ps1 -Help        Show this help"
    exit 0
}

# Create log file
New-Item -ItemType File -Path $LOG_FILE -Force | Out-Null

if ($Update) {
    Start-UpdateDeploy
} elseif ($Rollback) {
    Write-WarnLog "Rollback not yet implemented in Windows version"
} elseif ($Status) {
    Show-Status
} else {
    Start-InitialDeploy
}
