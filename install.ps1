$ErrorActionPreference = "Stop"

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Write-Host "Reiniciando instalador como administrador..."
    Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "`"$PSCommandPath`""
    )
    exit
}

$sourceDir = Split-Path -Parent $PSCommandPath
$gatewaySource = Join-Path $sourceDir "gateway\GymProAccessGateway.ps1"
$installDir = "C:\GymProAccess"
$defaultExe = "C:\TangoAccess\abrir.exe"
$defaultPort = 8787
$generatedToken = "gympro-" + [Guid]::NewGuid().ToString("N")

Write-Host "Instalador GymPro Access"
Write-Host "Destino: $installDir"
Write-Host ""

$exeInput = Read-Host "Ruta de abrir.exe [Enter = $defaultExe]"
$exePath = if ([string]::IsNullOrWhiteSpace($exeInput)) { $defaultExe } else { $exeInput.Trim() }

$portInput = Read-Host "Puerto local [Enter = $defaultPort]"
$port = if ([string]::IsNullOrWhiteSpace($portInput)) { $defaultPort } else { [int]$portInput }

$tokenInput = Read-Host "Token local [Enter = generar automaticamente]"
$token = if ([string]::IsNullOrWhiteSpace($tokenInput)) { $generatedToken } else { $tokenInput.Trim() }

New-Item -ItemType Directory -Force -Path $installDir | Out-Null

Copy-Item -LiteralPath $gatewaySource -Destination (Join-Path $installDir "GymProAccessGateway.ps1") -Force

$config = [ordered]@{
    Host = "127.0.0.1"
    Port = $port
    ExecutablePath = $exePath
    WorkingDirectory = Split-Path -Parent $exePath
    WindowStyle = "Normal"
    RequireToken = $true
    Token = $token
    MinIntervalMs = 1500
}

$config | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $installDir "config.json") -Encoding UTF8

$startBat = @"
@echo off
cd /d C:\GymProAccess
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\GymProAccess\GymProAccessGateway.ps1"
"@
$startBat | Set-Content -LiteralPath (Join-Path $installDir "start-gateway.bat") -Encoding ASCII

$hiddenVbs = @"
Set shell = CreateObject("WScript.Shell")
shell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""C:\GymProAccess\GymProAccessGateway.ps1""", 0, False
"@
$hiddenVbs | Set-Content -LiteralPath (Join-Path $installDir "start-gateway-hidden.vbs") -Encoding ASCII

$testHealthPs1 = @'
$config = Get-Content -Raw -LiteralPath "$PSScriptRoot\config.json" | ConvertFrom-Json
$uri = "http://$($config.Host):$($config.Port)/health"
Invoke-RestMethod -Uri $uri -Method Get | ConvertTo-Json -Depth 5
'@
$testHealthPs1 | Set-Content -LiteralPath (Join-Path $installDir "test-health.ps1") -Encoding ASCII

$testOpenPs1 = @'
$config = Get-Content -Raw -LiteralPath "$PSScriptRoot\config.json" | ConvertFrom-Json
$uri = "http://$($config.Host):$($config.Port)/open"
$headers = @{ "X-GymPro-Gateway-Token" = [string]$config.Token }
Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -ContentType "application/json" -Body "{}" | ConvertTo-Json -Depth 5
'@
$testOpenPs1 | Set-Content -LiteralPath (Join-Path $installDir "test-open.ps1") -Encoding ASCII

$testHealthBat = @"
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0test-health.ps1"
pause
"@
$testHealthBat | Set-Content -LiteralPath (Join-Path $installDir "test-health.bat") -Encoding ASCII

$testOpenBat = @"
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0test-open.ps1"
pause
"@
$testOpenBat | Set-Content -LiteralPath (Join-Path $installDir "test-open.bat") -Encoding ASCII

$browserConfig = @"
CONFIGURACION DEL NAVEGADOR

1. Abrir GymPro en Chrome.
2. Iniciar sesion con el usuario del gym.
3. Presionar F12.
4. Abrir la pestana Console.
5. Pegar estas 4 lineas y presionar Enter:

localStorage.setItem("gympro.tangoAccess.enabled", "true");
localStorage.setItem("gympro.tangoAccess.url", "http://127.0.0.1:$port/open");
localStorage.setItem("gympro.tangoAccess.token", "$token");
location.reload();

"@
$browserConfig | Set-Content -LiteralPath (Join-Path $installDir "CONFIGURAR-NAVEGADOR.txt") -Encoding UTF8

$readme = @"
GYMPRO ACCESS - INSTALACION

Instalado en:
C:\GymProAccess

Archivos principales:
- GymProAccessGateway.ps1: conector local.
- config.json: configuracion.
- start-gateway.bat: inicia el conector visible.
- test-health.bat: prueba estado.
- test-open.bat: prueba apertura del molinete.
- CONFIGURAR-NAVEGADOR.txt: comandos para activar GymPro en Chrome.

Prueba:
1. Ejecutar C:\GymProAccess\test-health.bat
2. Verificar executableExists = true.
3. Verificar workingDirectory = C:\TangoAccess.
4. Ejecutar C:\GymProAccess\test-open.bat
5. El molinete debe abrir.

"@
$readme | Set-Content -LiteralPath (Join-Path $installDir "README-INSTALACION.txt") -Encoding UTF8

$urlAcl = "http://127.0.0.1:$port/"
$runUser = "$env:USERDOMAIN\$env:USERNAME"

try {
    & netsh http delete urlacl url=$urlAcl | Out-Null
} catch {
}

try {
    & netsh http add urlacl url=$urlAcl user="$runUser" | Out-Null
    Write-Host "URL local habilitada para $runUser"
} catch {
    Write-Warning "No se pudo crear URL ACL. Si el gateway no inicia, ejecutar instalador como administrador."
}

try {
    $taskName = "GymPro TangoAccess Gateway"
    $action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$installDir\start-gateway-hidden.vbs`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $principal = New-ScheduledTaskPrincipal -UserId $runUser -LogonType Interactive -RunLevel LeastPrivilege
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
    Write-Host "Tarea de inicio creada: $taskName"
} catch {
    Write-Warning "No se pudo crear la tarea de inicio automatico. Se puede usar start-gateway.bat manualmente."
}

try {
    Start-Process -FilePath "wscript.exe" -ArgumentList "`"$installDir\start-gateway-hidden.vbs`"" -WindowStyle Hidden
    Start-Sleep -Seconds 2
    $health = Invoke-RestMethod -Uri "http://127.0.0.1:$port/health" -Method Get
    Write-Host ""
    Write-Host "Gateway iniciado."
    Write-Host "executableExists: $($health.executableExists)"
    Write-Host "tokenConfigured: $($health.tokenConfigured)"
} catch {
    Write-Warning "Instalacion copiada, pero no se pudo confirmar el gateway iniciado. Ejecutar C:\GymProAccess\start-gateway.bat para ver el error."
}

if (-not (Test-Path -LiteralPath $exePath)) {
    Write-Warning "No se encontro $exePath. El proveedor del molinete debe instalar ese archivo."
}

Write-Host ""
Write-Host "Instalacion terminada."
Write-Host "Siguiente paso: abrir C:\GymProAccess\CONFIGURAR-NAVEGADOR.txt y activar Chrome."
